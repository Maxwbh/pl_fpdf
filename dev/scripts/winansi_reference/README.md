# Referência WinAnsi

**Documento de manutenção.** Não faz parte da biblioteca.

O dicionário da fonte no PDF declara `/Encoding /WinAnsiEncoding`. O texto sai
do banco em AL32UTF8 e precisa ser traduzido para essa codificação antes de
entrar no stream de conteúdo — senão cada caractere acentuado vira dois glifos,
sem erro nenhum, num arquivo que abre normalmente.

| Arquivo | O quê |
|---|---|
| `winansi_reference.py` | a tabela, obtida do codec `cp1252` do Python — nada digitado à mão |
| `validate.py` | confere a tabela contra o **MuPDF**, montando um PDF e extraindo o texto de volta |

```
python dev/scripts/winansi_reference/validate.py
```

## O que a validação estabeleceu

- **251** posições definidas, não 224 como estimado quando o defeito foi
  relatado. As cinco indefinidas são `0x81`, `0x8D`, `0x8F`, `0x90` e `0x9D`.
- Das 217 posições desenháveis, o MuPDF devolve **todas** com o caractere que a
  tabela prevê — exceto duas, e as duas são o comportamento que o Anexo D do
  PDF manda: `0xA0` volta como espaço e `0xAD` como hífen.
- Uma linha só com os 218 bytes **sai da página**, e o MuPDF extrai apenas o
  que está dentro do papel. A primeira versão do validador parava no byte
  `0x85` sem erro nenhum e parecia uma divergência da tabela. Por isso os bytes
  são escritos em linhas de 40.

## Por que existe antes do PL/SQL

Método da base: referência em Python validada contra decodificador
independente, e só então a porta. Aqui isso separa "a tabela está certa
segundo a Unicode" de "um leitor de PDF desenha o glifo certo naquela
posição" — que é o que interessa, porque o destino do dado é um stream
declarado WinAnsi.
