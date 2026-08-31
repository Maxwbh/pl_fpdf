# -*- coding: utf-8 -*-
"""
Referencia dos codigos de barras lineares que serao portados para PL/SQL.

Cada funcao devolve uma string de modulos: '1' = barra, '0' = espaco.
Escrito com as mesmas tabelas e a mesma ordem de operacoes do PL/SQL.
"""

# ------------------------------------------------------------------ CODE39 ---
# 9 elementos por caractere (b s b s b s b s b), n=1 / w=3, separados por 1 espaco
C39 = {
 '0':'nnnwwnwnn','1':'wnnwnnnnw','2':'nnwwnnnnw','3':'wnwwnnnnn','4':'nnnwwnnnw',
 '5':'wnnwwnnnn','6':'nnwwwnnnn','7':'nnnwnnwnw','8':'wnnwnnwnn','9':'nnwwnnwnn',
 'A':'wnnnnwnnw','B':'nnwnnwnnw','C':'wnwnnwnnn','D':'nnnnwwnnw','E':'wnnnwwnnn',
 'F':'nnwnwwnnn','G':'nnnnnwwnw','H':'wnnnnwwnn','I':'nnwnnwwnn','J':'nnnnwwwnn',
 'K':'wnnnnnnww','L':'nnwnnnnww','M':'wnwnnnnwn','N':'nnnnwnnww','O':'wnnnwnnwn',
 'P':'nnwnwnnwn','Q':'nnnnnnwww','R':'wnnnnnwwn','S':'nnwnnnwwn','T':'nnnnwnwwn',
 'U':'wwnnnnnnw','V':'nwwnnnnnw','W':'wwwnnnnnn','X':'nwnnwnnnw','Y':'wwnnwnnnn',
 'Z':'nwwnwnnnn','-':'nwnnnnwnw','.':'wwnnnnwnn',' ':'nwwnnnwnn','$':'nwnwnwnnn',
 '/':'nwnwnnnwn','+':'nwnnnwnwn','%':'nnnwnwnwn','*':'nwnnwnwnn',
}

def code39(data, ratio=3):
    txt = '*' + data.upper() + '*'
    out = []
    for i, ch in enumerate(txt):
        if ch not in C39:
            raise ValueError(f'CODE39 nao aceita o caractere {ch!r}')
        pat = C39[ch]
        for j, w in enumerate(pat):
            n = ratio if w == 'w' else 1
            out.append(('1' if j % 2 == 0 else '0') * n)
        if i < len(txt) - 1:
            out.append('0')          # espaco separador entre caracteres
    return ''.join(out)

# ----------------------------------------------------------------- CODE128 ---
# 107 padroes; cada um com 6 larguras (b s b s b s) somando 11 modulos
C128 = [
 '212222','222122','222221','121223','121322','131222','122213','122312','132212',
 '221213','221312','231212','112232','122132','122231','113222','123122','123221',
 '223211','221132','221231','213212','223112','312131','311222','321122','321221',
 '312212','322112','322211','212123','212321','232121','111323','131123','131321',
 '112313','132113','132311','211313','231113','231311','112133','112331','132131',
 '113123','113321','133121','313121','211331','231131','213113','213311','213131',
 '311123','311321','331121','312113','312311','332111','314111','221411','431111',
 '111224','111422','121124','121421','141122','141221','112214','112412','122114',
 '122411','142112','142211','241211','221114','413111','241112','134111','111242',
 '121142','121241','114212','124112','124211','411212','421112','421211','212141',
 '214121','412121','111143','111341','131141','114113','114311','411113','411311',
 '113141','114131','311141','411131','211412','211214','211232','2331112',
]
START_B, START_C, STOP = 104, 105, 106

def code128(data):
    """Usa Code C (pares de digitos) quando o dado e todo numerico e par; senao Code B."""
    if data.isdigit() and len(data) % 2 == 0:
        codes = [START_C] + [int(data[i:i+2]) for i in range(0, len(data), 2)]
    else:
        for ch in data:
            if not (32 <= ord(ch) <= 126):
                raise ValueError('CODE128 (Code B) aceita apenas ASCII 32..126')
        codes = [START_B] + [ord(ch) - 32 for ch in data]
    chk = codes[0]
    for i, c in enumerate(codes[1:], start=1):
        chk += i * c
    codes.append(chk % 103)
    codes.append(STOP)
    out = []
    for c in codes:
        pat = C128[c]
        for j, w in enumerate(pat):
            out.append(('1' if j % 2 == 0 else '0') * int(w))
    return ''.join(out)

# ------------------------------------------------------------- EAN13 / EAN8 ---
EAN_L = ['0001101','0011001','0010011','0111101','0100011',
         '0110001','0101111','0111011','0110111','0001011']
EAN_G = [s[::-1].replace('0','x').replace('1','0').replace('x','1') for s in EAN_L]
EAN_R = [s.replace('0','x').replace('1','0').replace('x','1') for s in EAN_L]
EAN_PARITY = ['LLLLLL','LLGLGG','LLGGLG','LLGGGL','LGLLGG',
              'LGGLLG','LGGGLL','LGLGLG','LGLGGL','LGGLGL']

def ean_check(digits):
    s = 0
    for i, d in enumerate(reversed(digits)):
        s += int(d) * (3 if i % 2 == 0 else 1)
    return (10 - s % 10) % 10

def ean13(data):
    d = ''.join(ch for ch in data if ch.isdigit())
    if len(d) == 12:
        d += str(ean_check(d))
    if len(d) != 13:
        raise ValueError('EAN13 exige 12 digitos (calcula o verificador) ou 13')
    if int(d[12]) != ean_check(d[:12]):
        raise ValueError('EAN13: digito verificador invalido')
    par = EAN_PARITY[int(d[0])]
    out = ['101']
    for i, ch in enumerate(d[1:7]):
        out.append(EAN_L[int(ch)] if par[i] == 'L' else EAN_G[int(ch)])
    out.append('01010')
    for ch in d[7:]:
        out.append(EAN_R[int(ch)])
    out.append('101')
    return ''.join(out)

def ean8(data):
    d = ''.join(ch for ch in data if ch.isdigit())
    if len(d) == 7:
        d += str(ean_check(d))
    if len(d) != 8:
        raise ValueError('EAN8 exige 7 digitos (calcula o verificador) ou 8')
    out = ['101'] + [EAN_L[int(c)] for c in d[:4]] + ['01010'] + \
          [EAN_R[int(c)] for c in d[4:]] + ['101']
    return ''.join(out)

# ------------------------------------------------------------------- ITF14 ---
ITF = ['nnwwn','wnnnw','nwnnw','wwnnn','nnwnw','wnwnn','nwwnn','nnnww','wnnwn','nwnwn']

def itf(data, ratio=3):
    """Interleaved 2 of 5 puro: qualquer quantidade PAR de digitos, sem
    verificador.

    E o que o boleto bancario usa — 44 digitos, sem digito de controle no
    simbolo (o verificador do boleto esta DENTRO dos 44, na posicao 5, e nao e
    calculado pela simbologia). O ITF14 e um caso particular disto, com 14
    digitos e verificador proprio.
    """
    d = ''.join(ch for ch in data if ch.isdigit())
    if not d:
        raise ValueError('ITF: nenhum digito')
    if len(d) % 2 == 1:
        d = '0' + d                      # ITF exige quantidade par de digitos
    out = ['1010']                       # start: n n n n
    for i in range(0, len(d), 2):
        a, b = ITF[int(d[i])], ITF[int(d[i+1])]
        for j in range(5):
            out.append('1' * (ratio if a[j] == 'w' else 1))
            out.append('0' * (ratio if b[j] == 'w' else 1))
    out.append('1' * ratio + '0' + '1')  # stop: w n n
    return ''.join(out)

def itf14(data, ratio=3):
    d = ''.join(ch for ch in data if ch.isdigit())
    if len(d) == 13:
        d += str(ean_check(d))
    if len(d) != 14:
        raise ValueError('ITF14 exige 13 digitos (calcula o verificador) ou 14')
    return itf(d, ratio)

# --------------------------------------------------------------------- api ---
def make(data, tipo, ratio=3):
    t = tipo.upper()
    if t == 'CODE39':  return code39(data, ratio)
    if t == 'CODE128': return code128(data)
    if t == 'EAN13':   return ean13(data)
    if t == 'EAN8':    return ean8(data)
    if t == 'ITF14':   return itf14(data, ratio)
    if t == 'ITF':     return itf(data, ratio)
    raise ValueError(f'Simbologia nao suportada: {tipo}')
