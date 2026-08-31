# -*- coding: utf-8 -*-
"""
Referência da cifragem sobre object streams (PDF 1.5+), a ser portada.

O que falta no package
----------------------
`EncryptPDF` e `DecryptPDF` reescrevem o arquivo **objeto a objeto, por
offset**, e montam uma xref clássica nova. Num PDF 1.5+ isso não fecha: os
objetos que moram dentro de um *object stream* não têm offset no arquivo, e os
próprios `/Type /ObjStm` e `/Type /XRef` não podem ser copiados — eles descrevem
uma estrutura que o arquivo de saída não vai mais ter. Hoje o package recusa com
`ORA-20849`, o que é honesto e insuficiente.

A saída é **achatar**: desmontar os object streams, emitir cada objeto de dentro
como objeto de primeiro nível, descartar os `ObjStm`/`XRef` e escrever uma xref
clássica. O copiador já faz isso para merge e extract; aqui é o mesmo movimento,
com a cifragem no meio.

A assimetria que decide o resultado
-----------------------------------
Esta é a parte que uma porta feita direto erra, e erra em silêncio.

Dentro de um object stream as strings **não são cifradas individualmente**: o
que se cifra é o stream inteiro, de uma vez (PDF 32000-1, 7.5.7). Fora dele,
cada string é cifrada com a chave do seu próprio objeto. Então, ao achatar:

- **Cifrando** um PDF em claro: o objeto sai de dentro do ObjStm e vira objeto
  de primeiro nível. Suas strings passam a precisar de cifragem própria — que
  antes não existia.
- **Decifrando** um PDF cifrado: depois de decifrar e inflar o ObjStm, as
  strings de dentro **já estão em claro**. Passá-las pela decifragem de novo as
  transforma em lixo.

Errar isso não quebra o arquivo: ele abre, as páginas aparecem, e só o título
ou o texto de uma anotação sai embaralhado. É o gênero de defeito que passa por
um teste que só conta páginas.

A ordem das operações no ObjStm
-------------------------------
Ao ler um PDF cifrado, o payload do ObjStm precisa ser **decifrado antes de
inflado** — é um stream como outro qualquer. A xref em stream, ao contrário,
**nunca** é cifrada: o leitor precisa dela para achar o próprio `/Encrypt`.
"""
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
for _d in ('pdfxref_reference', 'pdfcrypt_reference', 'pdfaes_reference'):
    _p = os.path.join(AQUI, '..', _d)
    if _p not in sys.path:
        sys.path.insert(0, _p)

from pdfxref_reference import (corpo_do_objeto, dict_value,  # noqa: E402
                               indexar, refs)
import pdfcrypt_reference as rc4ref                          # noqa: E402
import pdfaes_reference as aesref                            # noqa: E402


class ErroCrypt(Exception):
    pass


# ─────────────────────────────── achatar ─────────────────────────────────────

class Objeto(object):
    """Um objeto pronto para ser emitido no arquivo de saída."""
    __slots__ = ('oid', 'dic', 'payload', 'de_objstm')

    def __init__(self, oid, dic, payload, de_objstm):
        self.oid = oid
        self.dic = dic                # texto, sem o cabeçalho 'N G obj'
        self.payload = payload        # bytes do stream, ou None
        self.de_objstm = de_objstm    # veio de dentro de um object stream?


def e_estrutura(dic):
    """O objeto é um /Type /ObjStm ou /Type /XRef?

    Estes dois descrevem a estrutura do arquivo de ORIGEM. Copiá-los para uma
    saída de xref clássica produziria um arquivo que se descreve de duas formas
    contraditórias — e a que o leitor escolher não é a nossa.
    """
    return dict_value(dic, b'/Type') in (b'/ObjStm', b'/XRef')


def achatar(pdf, decifra_stream=None):
    """Desmonta os object streams. Devolve (objetos, root_ref, info_ref).

    `decifra_stream(oid, dados) -> bytes` é obrigatório quando a origem está
    cifrada: sem ele o ObjStm não infla.
    """
    idx = indexar(pdf, decifra=decifra_stream)

    objetos = []
    for oid in sorted(idx.xref):
        if oid in idx.corpos:
            corpo = idx.corpos[oid]
            if e_estrutura(corpo):
                continue              # não deveria acontecer, mas é barato
            objetos.append(Objeto(oid, corpo, None, True))
            continue

        ent = idx.xref[oid]
        if ent.tipo != 1:
            continue
        dic, payload = corpo_do_objeto(pdf, ent.a)
        # tira o cabeçalho 'N G obj'
        i = dic.find(b'obj')
        dic = dic[i + 3:] if i >= 0 else dic
        if e_estrutura(dic):
            continue
        objetos.append(Objeto(oid, dic.strip(), payload or None, False))

    # /Root e /Info saem do trailer REAL — num PDF 1.5+ ele é o dicionário da
    # xref em stream. A versão anterior do EncryptPDF procurava /Root com uma
    # regex nos últimos 4000 bytes do arquivo, o que funciona por acidente e
    # falha num arquivo com atualização incremental.
    trailer = _ultimo_trailer(pdf, idx)
    info = refs(dict_value(trailer, b'/Info')) if trailer else []
    return objetos, idx.root, (info[0] if info else None)


def _ultimo_trailer(pdf, idx):
    """Dicionário da seção de xref mais recente."""
    if not idx.secoes:
        return None
    tipo, off = idx.secoes[0]
    if tipo == 'tabela':
        fim = pdf.find(b'trailer', off)
        return pdf[fim:fim + 4096] if fim >= 0 else None
    dic, _ = corpo_do_objeto(pdf, off)
    return dic


# ─────────────────────────────── montar ──────────────────────────────────────

def montar(objetos, root, info=None, extras=(), trailer_extra=b'',
           versao=b'1.7'):
    """Escreve um PDF com xref clássica a partir da lista de objetos.

    `extras` são objetos já formatados como `(oid, bytes_do_corpo)` — é por onde
    entra o dicionário /Encrypt, que não passa pela cifragem.
    """
    buf = bytearray(b'%PDF-' + versao + b'\n%\xe2\xe3\xcf\xd3\n')
    offs = {}

    for o in objetos:
        offs[o.oid] = len(buf)
        buf += b'%d 0 obj' % o.oid + o.dic
        if o.payload is not None:
            buf += b'\nstream\n' + o.payload + b'\nendstream'
        buf += b'\nendobj\n'

    for oid, corpo in extras:
        offs[oid] = len(buf)
        buf += b'%d 0 obj' % oid + corpo + b'\nendobj\n'

    tam = max(offs) + 1 if offs else 1
    inicio = len(buf)
    buf += b'xref\n0 %d\n' % tam
    buf += b'0000000000 65535 f \n'
    for i in range(1, tam):
        if i in offs:
            buf += b'%010d 00000 n \n' % offs[i]
        else:
            # Achatar deixa buracos: os ObjStm e a XRef da origem não são
            # emitidos. A xref clássica os declara LIVRES, que é o que a
            # especificação manda para um id que não existe mais.
            buf += b'0000000000 65535 f \n'

    buf += b'trailer\n<< /Size %d /Root %d 0 R' % (tam, root)
    if info is not None:
        buf += b' /Info %d 0 R' % info
    buf += trailer_extra + b' >>\n'
    buf += b'startxref\n%d\n%%%%EOF\n' % inicio
    return bytes(buf)


# ──────────────────────────── /Encrypt: leitura ──────────────────────────────

def dicionario_encrypt(pdf):
    """Dicionário /Encrypt do documento, como texto. None se não houver.

    `materializar=False`: o /Encrypt tem de ser lido ANTES de abrir os object
    streams, porque num PDF cifrado eles só abrem com a chave que sai daqui.
    """
    idx = indexar(pdf, materializar=False)
    trailer = _ultimo_trailer(pdf, idx)
    if trailer is None:
        return None, None
    val = dict_value(trailer, b'/Encrypt')
    if val is None:
        return None, None
    ids = refs(val)
    if not ids:                       # /Encrypt direto no trailer (raro)
        return val, None
    oid = ids[0]
    ent = idx.xref.get(oid)
    if ent is None or ent.tipo != 1:
        raise ErroCrypt('/Encrypt aponta para objeto ausente')
    dic, _ = corpo_do_objeto(pdf, ent.a)
    i = dic.find(b'obj')
    return (dic[i + 3:] if i >= 0 else dic), oid


def primeiro_id(pdf):
    """Primeiro elemento do /ID do trailer, em bytes. Participa da chave."""
    idx = indexar(pdf, materializar=False)
    trailer = _ultimo_trailer(pdf, idx)
    val = dict_value(trailer, b'/ID') if trailer else None
    if val is None:
        return b''
    m = re.search(rb'<([0-9A-Fa-f]*)>', val)
    return bytes.fromhex(m.group(1).decode()) if m else b''


def _int(dic, chave, padrao=None):
    v = dict_value(dic, chave)
    if v is None:
        return padrao
    return int(re.sub(rb'[^0-9-]', b'', v) or b'0')


def _hexstr(dic, chave):
    v = dict_value(dic, chave)
    if v is None:
        # dict_value não devolve string literal; procura à mão
        i = dic.find(chave)
        if i < 0:
            return None
        j = i + len(chave)
        while j < len(dic) and dic[j:j + 1] in b' \t\r\n':
            j += 1
        if dic[j:j + 1] == b'<':
            k = dic.find(b'>', j)
            return bytes.fromhex(dic[j + 1:k].decode())
        if dic[j:j + 1] == b'(':
            k = j + 1
            out = bytearray()
            while k < len(dic) and dic[k:k + 1] != b')':
                if dic[k:k + 1] == b'\\':
                    k += 1
                out += dic[k:k + 1]
                k += 1
            return bytes(out)
    return None


def chave_do_arquivo(pdf, senha):
    """(chave, revisao, aes, n_bytes, oid_encrypt) do documento cifrado."""
    dic, oid = dicionario_encrypt(pdf)
    if dic is None:
        raise ErroCrypt('o PDF nao esta cifrado')
    rev = _int(dic, b'/R')
    bits = _int(dic, b'/Length', 40)
    perms = _int(dic, b'/P', -1)
    o_val = _hexstr(dic, b'/O')
    aes = b'AESV2' in dic or b'AESV3' in dic
    if rev >= 5:
        raise ErroCrypt('R6 (AES-256) fica para a porta; aqui o alvo e V4')
    chave = rc4ref.encryption_key(senha.encode(), o_val, perms,
                                  primeiro_id(pdf), bits // 8, rev)
    return chave, rev, aes, bits // 8, oid


def decifrador(chave, aes):
    """Função `(oid, dados) -> bytes` que desfaz a cifra de um stream."""
    def desfaz(oid, dados):
        if not dados:
            return dados
        if aes:
            ok = aesref.chave_do_objeto_aes(chave, oid, 0)
            return aesref.aes_cbc_decifrar(ok, dados)
        return rc4ref.rc4(rc4ref.object_key(chave, oid, 0), dados)
    return desfaz


def cifrador(chave, aes):
    def faz(oid, dados):
        if not dados:
            return dados
        if aes:
            ok = aesref.chave_do_objeto_aes(chave, oid, 0)
            return aesref.aes_cbc_cifrar(ok, dados)
        return rc4ref.rc4(rc4ref.object_key(chave, oid, 0), dados)
    return faz


# ───────────────────────── cifrar / decifrar achatando ───────────────────────

def cifrar(pdf, senha_usuario, senha_dono=None, aes=False, perms=-4,
           file_id=b'\x01' * 16):
    """Achata os object streams e cifra o resultado. Devolve o PDF protegido."""
    objetos, root, info = achatar(pdf)
    n = 16 if aes else 16             # V4 usa 128 bits nos dois filtros
    rev = 4
    o_val = rc4ref.owner_value((senha_dono or senha_usuario).encode(),
                               senha_usuario.encode(), n, rev)
    chave = rc4ref.encryption_key(senha_usuario.encode(), o_val, perms,
                                  file_id, n, rev)
    u_val = rc4ref.user_value(chave, file_id, rev)
    cifra = cifrador(chave, aes)

    for o in objetos:
        ok_rc4 = rc4ref.object_key(chave, o.oid, 0)
        # AQUI está a assimetria: o objeto que veio de dentro de um ObjStm
        # nunca teve as strings cifradas — elas iam junto no stream. Agora que
        # ele é objeto de primeiro nível, precisa delas cifradas.
        o.dic = rc4ref.cifrar_strings(o.dic, ok_rc4) if not aes \
            else _cifrar_strings_aes(o.dic, chave, o.oid)  # noqa: E501
        if o.payload is not None:
            o.payload = cifra(o.oid, o.payload)
            o.dic = re.sub(rb'/Length\s+\d+',
                           b'/Length %d' % len(o.payload), o.dic, count=1)

    enc = (b'<< /Filter /Standard /V 4 /R 4 /Length 128 /P %d'
           b' /CF << /StdCF << /CFM /%s /AuthEvent /DocOpen /Length 16 >> >>'
           b' /StmF /StdCF /StrF /StdCF'
           b' /O <%s> /U <%s> >>'
           % (perms, b'AESV2' if aes else b'V2',
              o_val.hex().upper().encode(), u_val.hex().upper().encode()))
    oid_enc = (max(o.oid for o in objetos) + 1) if objetos else 1
    idhex = file_id.hex().upper().encode()
    return montar(objetos, root, info, extras=[(oid_enc, enc)],
                  trailer_extra=b' /Encrypt %d 0 R /ID [<%s><%s>]'
                                % (oid_enc, idhex, idhex))


def _cifrar_strings_aes(dic, chave, oid):
    ok = aesref.chave_do_objeto_aes(chave, oid, 0)
    return rc4ref.percorrer_strings(dic, lambda t: aesref.aes_cbc_cifrar(ok, t))


def _decifrar_strings(dic, chave, oid, aes):
    if aes:
        ok = aesref.chave_do_objeto_aes(chave, oid, 0)
        return rc4ref.percorrer_strings(
            dic, lambda t: aesref.aes_cbc_decifrar(ok, t))
    ok = rc4ref.object_key(chave, oid, 0)
    return rc4ref.cifrar_strings(dic, ok)      # RC4 é o seu próprio inverso


def decifrar(pdf, senha, decifrar_strings_do_objstm=False):
    """Achata e remove a proteção. Devolve o PDF em claro.

    `decifrar_strings_do_objstm` existe só para o teste provar que a assimetria
    importa: ligado, ele faz o que uma porta desatenta faria — decifrar de novo
    uma string que já saiu em claro de dentro do object stream.
    """
    chave, rev, aes, n, oid_enc = chave_do_arquivo(pdf, senha)
    objetos, root, info = achatar(pdf, decifra_stream=decifrador(chave, aes))
    desfaz = decifrador(chave, aes)

    saida = []
    for o in objetos:
        if o.oid == oid_enc:
            continue                  # o /Encrypt sai do arquivo
        if not o.de_objstm or decifrar_strings_do_objstm:
            o.dic = _decifrar_strings(o.dic, chave, o.oid, aes)
        if o.payload is not None:
            o.payload = desfaz(o.oid, o.payload)
            o.dic = re.sub(rb'/Length\s+\d+',
                           b'/Length %d' % len(o.payload), o.dic, count=1)
        saida.append(o)
    return montar(saida, root, info)
