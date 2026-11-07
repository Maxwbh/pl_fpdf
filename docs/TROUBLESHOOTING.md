# Problemas comuns — PL_FPDF

[**English**](TROUBLESHOOTING_EN.md) · [Índice da documentação](README.md)

Organizado pelo que você **vê**: a mensagem de erro ou o sintoma. Para a lista
completa de códigos, por faixa, veja os
[códigos de erro](DOCUMENTATION.md#18-códigos-de-erro); por API, a
[referência](API_REFERENCE.md).

Antes de tudo, a versão instalada — muitos sintomas abaixo dependem dela:

```sql
BEGIN DBMS_OUTPUT.PUT_LINE(PL_FPDF.co_version); END;
/
```

---

## Instalação e acesso

| Você vê | Causa | O que fazer |
|---------|-------|-------------|
| `ORA-01031: insufficient privileges` ao instalar | falta `CREATE PROCEDURE` no schema | peça o grant ao DBA |
| Objetos `INVALID` depois de instalar | erro de compilação | `SELECT * FROM user_errors WHERE name LIKE 'PL_FPDF%'`. Banco anterior ao 19c não é suportado |
| `PLS-00201: identifier 'PL_FPDF_UTIL' must be declared` | instalação pelo clone na ordem errada | compile o `PL_FPDF_UTIL` antes do `PL_FPDF` — ou use o `dist/pl_fpdf_install.sql`, que já vem na ordem |
| `ORA-06553: PLS-221: 'CO_VERSION' is not a procedure` | `SELECT PL_FPDF.co_version FROM DUAL` | constante de package não se lê em SQL. Use o bloco do topo desta página |
| `ORA-04068: existing state of packages has been discarded` (às vezes com `ORA-04061`, `ORA-04065` ou `ORA-06508`) | o package foi reinstalado ou recompilado enquanto a sessão o usava | esperado depois de atualizar, em cada sessão que já o usava — em pool, em cada conexão. O documento em montagem naquela sessão se perdeu: refaça a operação desde o `Init`. Ver [Instalação §7](INSTALLATION.md#7-atualizar) |
| `PLS-00201: identifier 'PL_FPDF' must be declared` em outro schema | falta grant ou sinônimo | `GRANT EXECUTE ON PL_FPDF TO app` e um sinônimo — ver [Instalação §6](INSTALLATION.md#6-usar-a-partir-de-outro-schema) |
| `ORA-29275: partial multibyte character` no primeiro `SetFont` | 3.3.0 (ou 3.4.0-rc1) num Oracle **26ai** com AL32UTF8 | instale a 3.4.0 ou mais nova — ver [Compatibilidade](COMPATIBILITY.md#1-versões-do-oracle) |

## Gerando o documento

| Você vê | Causa | O que fazer |
|---------|-------|-------------|
| `ORA-20005: PL_FPDF not initialized. Call Init() first.` | chamada antes do `Init` — ou o documento foi começado em outra requisição | todo documento começa com `Init` e termina com `OutputBlob` e `Reset` **na mesma chamada ao banco**. Em APEX e ORDS, cada requisição pode cair numa sessão diferente do pool: nunca espalhe um documento por duas requisições |
| Acento sai como dois caracteres estranhos (`Ã§` no lugar de `ç`) | 3.3.0 ou anterior | atualize para a 3.4.0. Se o seu código convertia o texto antes, retire a conversão — ver [Migração 3.3 → 3.4](MIGRATION.md#33--34) |
| `ORA-06502` no `GetStringWidth`, ou ao centralizar/alinhar à direita texto com acento | 3.3.0 ou anterior | atualize para a 3.4.0 |
| `ORA-20203` com uma posição | caractere fora do WinAnsi (ideograma, cirílico, emoji) numa fonte padrão | embuta uma fonte TrueType com `AddTTFFont` |
| `ORA-20601` | `AddLink`, `SetLink` ou link com destino numérico | só há link para URL — link interno não é suportado |
| `ORA-20100: PL_FPDF: Header : ... PLS-00201` | a procedure de cabeçalho/rodapé está em outro schema, e é chamada **pelo dono do PL_FPDF** | dê `GRANT EXECUTE` da procedure ao dono do PL_FPDF e passe o nome qualificado (`'APP.CABECALHO'`) — ver [Instalação §6](INSTALLATION.md#6-usar-a-partir-de-outro-schema) |
| `Image` recusa PNG com "Not a PNG file" | 3.3.0 ou anterior em banco AL32UTF8 | atualize para a 3.4.0 |
| `ORA-24247: network access denied by access control list` no `Image` | `Image` por URL sem ACL de rede para o dono do PL_FPDF | leia o arquivo para um BLOB e use `ImageFromBlob` (3.4.0), ou peça a ACL |
| `ORA-29280` ou `ORA-20401`…`ORA-20403` no `OutputFile` / `LoadTTFFromFile` | `DIRECTORY` inexistente ou sem `READ`/`WRITE` para o dono do PL_FPDF | confira o `DIRECTORY` e os grants **do dono** do package |
| `ORA-20306` | `Output` com destino `'I'`, `'D'` ou `'S'`, do FPDF clássico | use `OutputBlob` e entregue o BLOB — ver abaixo |
| `ORA-04030: out of process memory` | documento grande demais para a PGA da sessão | chame `Reset` entre documentos, libere os BLOBs temporários e gere em lotes |

## Entregando o PDF

| Você vê | Causa | O que fazer |
|---------|-------|-------------|
| O navegador mostra o **fonte** do PDF (`%PDF-1.4`, `obj`, `stream`) | resposta sem `Content-Type: application/pdf` | mande o cabeçalho antes do BLOB — ver [Entregar o PDF a um navegador](DOCUMENTATION.md#entregar-o-pdf-a-um-navegador) |
| Abre num navegador e não em outro | provavelmente o mesmo problema: navegadores diferem em quanto adivinham o tipo quando o `Content-Type` falta ou está errado, e isso muda de versão para versão | o mesmo conserto. Confira os cabeçalhos da resposta (F12 → Network) antes de suspeitar do PDF |
| Arquivo baixado vem corrompido | algo foi escrito no buffer HTTP **antes** do cabeçalho (`htp.p` de depuração, mensagem de exceção), ou o `Content-Length` não bate | gere o PDF inteiro antes de escrever qualquer cabeçalho; no APEX, encerre com `apex_application.stop_apex_engine` |

## Lendo e manipulando PDF

| Você vê | Causa | O que fazer |
|---------|-------|-------------|
| `ORA-20800`…`ORA-20810` no `LoadPDF` | o BLOB não é um PDF, ou tem cabeçalho, xref ou trailer corrompidos | confira o arquivo num leitor; se ele abre lá, abra uma issue com o PDF |
| `ORA-20867` no `LoadPDF` ou no `LoadPDFWithID` | o PDF de entrada está cifrado, e o `LoadPDF` não decifra | passe antes pelo `DecryptPDF`, com a senha. Até a 3.4.0-rc2 ele aceitava sem erro e as páginas saíam em branco |
| `ORA-20893` | um stream descomprimido passou do teto (8 MB por stream) | é a defesa contra arquivo-bomba. No `FlateDecode` direto, o teto é o `p_max_bytes` |
| `ORA-20858` | AES-128 pede PDF 1.5+, AES-256 pede 1.7+ | `SetPDFVersion('1.7')` antes do `SetEncryption` |

## Extensão PIX/Boleto

| Você vê | Causa | O que fazer |
|---------|-------|-------------|
| `ORA-20802: Due date too far in future (max factor 9999)` | extensão anterior ao conserto do fator de vencimento, que desde 22/02/2025 recomeça em 1000 | reinstale os packages da extensão a partir deste repositório: o conserto é de novembro de 2026 |
| `ORA-20701: Invalid PIX key ... for type PHONE` | chave de telefone sem o DDI | a chave de telefone do PIX é `+55` + DDD + número |

---

Não achou o seu caso? Abra uma [issue](https://github.com/Maxwbh/pl_fpdf/issues)
com a versão do PL_FPDF, a do Oracle, o charset do banco
(`SELECT value FROM nls_database_parameters WHERE parameter = 'NLS_CHARACTERSET'`)
e a mensagem de erro inteira.
