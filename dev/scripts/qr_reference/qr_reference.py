# -*- coding: utf-8 -*-
"""
Referencia do codificador QR (modo byte) que sera portado para PL/SQL.
Escrito com as mesmas estruturas que o PL/SQL usara (tabelas simples, aritmetica
inteira), para que a portabilidade seja mecanica e verificavel.

Validado contra segno em qr_validate.py.
"""

# ---------------------------------------------------------------- tabelas ----
# Total de codewords (dados + correcao) por versao 1..40
TOTAL_CW = [None,
    26,44,70,100,134,172,196,242,292,346,404,466,532,581,655,733,815,901,991,1085,
    1156,1258,1364,1474,1588,1706,1828,1921,2051,2185,2323,2465,2611,2761,2876,3034,
    3196,3362,3532,3706]

# (ec_cw_por_bloco, blocos_g1, dados_g1, blocos_g2, dados_g2) por versao e nivel
ECC = {
 'L': [None,(7,1,19,0,0),(10,1,34,0,0),(15,1,55,0,0),(20,1,80,0,0),(26,1,108,0,0),
       (18,2,68,0,0),(20,2,78,0,0),(24,2,97,0,0),(30,2,116,0,0),(18,2,68,2,69),
       (20,4,81,0,0),(24,2,92,2,93),(26,4,107,0,0),(30,3,115,1,116),(22,5,87,1,88),
       (24,5,98,1,99),(28,1,107,5,108),(30,5,120,1,121),(28,3,113,4,114),(28,3,107,5,108)],
 'M': [None,(10,1,16,0,0),(16,1,28,0,0),(26,1,44,0,0),(18,2,32,0,0),(24,2,43,0,0),
       (16,4,27,0,0),(18,4,31,0,0),(22,2,38,2,39),(22,3,36,2,37),(26,4,43,1,44),
       (30,1,50,4,51),(22,6,36,2,37),(22,8,37,1,38),(24,4,40,5,41),(24,5,41,5,42),
       (28,7,45,3,46),(28,10,46,1,47),(26,9,43,4,44),(26,3,44,11,45),(26,3,41,13,42)],
 'Q': [None,(13,1,13,0,0),(22,1,22,0,0),(18,2,17,0,0),(26,2,24,0,0),(18,2,15,2,16),
       (24,4,19,0,0),(18,2,14,4,15),(22,4,18,2,19),(20,4,16,4,17),(24,6,19,2,20),
       (28,4,22,4,23),(26,4,20,6,21),(24,8,20,4,21),(20,11,16,5,17),(30,5,24,7,25),
       (24,15,19,2,20),(28,1,22,15,23),(28,17,22,1,23),(26,17,21,4,22),(30,15,24,5,25)],
 'H': [None,(17,1,9,0,0),(28,1,16,0,0),(22,2,13,0,0),(16,4,9,0,0),(22,2,11,2,12),
       (28,4,15,0,0),(26,4,13,1,14),(26,4,14,2,15),(24,4,12,4,13),(28,6,15,2,16),
       (24,3,12,8,13),(28,7,14,4,15),(22,12,11,4,12),(24,11,12,5,13),(24,11,12,7,13),
       (30,3,15,13,16),(28,2,14,17,15),(28,2,14,19,15),(26,9,13,16,14),(28,15,15,10,16)],
}
MAX_VER = 20   # cobre ate ~858 bytes (nivel L); PIX cabe com folga

# Posicoes dos padroes de alinhamento por versao
ALIGN = [None,[],[6,18],[6,22],[6,26],[6,30],[6,34],[6,22,38],[6,24,42],[6,26,46],
    [6,28,50],[6,30,54],[6,32,58],[6,34,62],[6,26,46,66],[6,26,48,70],[6,26,50,74],
    [6,30,54,78],[6,30,56,82],[6,30,58,86],[6,34,62,90]]

ECC_BITS = {'L':0b01,'M':0b00,'Q':0b11,'H':0b10}

# ------------------------------------------------------------- GF(256) -------
EXP=[0]*512; LOG=[0]*256
_x=1
for _i in range(255):
    EXP[_i]=_x; LOG[_x]=_i
    _x<<=1
    if _x & 0x100: _x ^= 0x11D
for _i in range(255,512): EXP[_i]=EXP[_i-255]

def gf_mul(a,b):
    if a==0 or b==0: return 0
    return EXP[LOG[a]+LOG[b]]

def rs_generator(n):
    g=[1]
    for i in range(n):
        ng=[0]*(len(g)+1)
        for j,c in enumerate(g):
            ng[j]   ^= gf_mul(c, EXP[i])
            ng[j+1] ^= c
        g=ng
    # g sai em grau crescente; rs_ecc consome do maior grau para o menor
    return g[::-1]

def rs_ecc(data, n):
    gen=rs_generator(n)
    res=list(data)+[0]*n
    for i in range(len(data)):
        f=res[i]
        if f:
            for j,c in enumerate(gen):
                res[i+j] ^= gf_mul(c,f)
    return res[len(data):]

# ------------------------------------------------------------ codificacao ----
def choose_version(nbytes, ecl):
    for v in range(1, MAX_VER+1):
        ec,g1,d1,g2,d2 = ECC[ecl][v]
        cap = g1*d1 + g2*d2
        cci = 8 if v <= 9 else 16
        need = (4 + cci + nbytes*8 + 7)//8
        if need <= cap: return v
    raise ValueError('dados excedem a capacidade suportada')

def encode_data(data_bytes, ver, ecl):
    ec,g1,d1,g2,d2 = ECC[ecl][ver]
    total_data = g1*d1 + g2*d2
    bits=[]
    def put(val, n):
        for i in range(n-1,-1,-1): bits.append((val>>i)&1)
    put(0b0100, 4)                       # modo byte
    put(len(data_bytes), 8 if ver<=9 else 16)
    for b in data_bytes: put(b, 8)
    # terminador
    for _ in range(min(4, total_data*8 - len(bits))): bits.append(0)
    while len(bits) % 8: bits.append(0)
    cws=[int(''.join(map(str,bits[i:i+8])),2) for i in range(0,len(bits),8)]
    pad=[0xEC,0x11]; i=0
    while len(cws) < total_data:
        cws.append(pad[i%2]); i+=1
    # blocos + ECC
    blocks=[]; eccs=[]; pos=0
    for (cnt,dcw) in ((g1,d1),(g2,d2)):
        for _ in range(cnt):
            blk=cws[pos:pos+dcw]; pos+=dcw
            blocks.append(blk); eccs.append(rs_ecc(blk, ec))
    # intercalacao
    out=[]
    for i in range(max(len(b) for b in blocks)):
        for b in blocks:
            if i < len(b): out.append(b[i])
    for i in range(ec):
        for e in eccs: out.append(e[i])
    return out

# ----------------------------------------------------------------- matriz ----
def build_matrix(ver, ecl, codewords, mask=None):
    size = 17 + 4*ver
    m=[[None]*size for _ in range(size)]
    res=[[False]*size for _ in range(size)]   # posicao reservada (funcional)

    def finder(r,c):
        for i in range(-1,8):
            for j in range(-1,8):
                rr,cc=r+i,c+j
                if 0<=rr<size and 0<=cc<size:
                    inside = 0<=i<7 and 0<=j<7
                    dark = inside and (i in (0,6) or j in (0,6) or (2<=i<=4 and 2<=j<=4))
                    m[rr][cc]= 1 if dark else 0
                    res[rr][cc]=True
    finder(0,0); finder(0,size-7); finder(size-7,0)

    for i in range(8, size-8):            # timing
        v = 1 if i%2==0 else 0
        if m[6][i] is None: m[6][i]=v; res[6][i]=True
        if m[i][6] is None: m[i][6]=v; res[i][6]=True

    for r in ALIGN[ver]:                  # alinhamento
        for c in ALIGN[ver]:
            # pula apenas os que colidem com os tres finders; os que cruzam a
            # linha de temporizacao DEVEM ser desenhados (sobrepoem o timing)
            if (r <= 8 and c <= 8) or (r <= 8 and c >= size-9) or (r >= size-9 and c <= 8):
                continue
            for i in range(-2,3):
                for j in range(-2,3):
                    dark = max(abs(i),abs(j)) != 1
                    m[r+i][c+j]= 1 if dark else 0
                    res[r+i][c+j]=True

    m[size-8][8]=1; res[size-8][8]=True   # modulo escuro

    for i in range(9):                    # area reservada de formato
        if not res[8][i]: m[8][i]=0; res[8][i]=True
        if not res[i][8]: m[i][8]=0; res[i][8]=True
    for i in range(8):
        if not res[8][size-1-i]: m[8][size-1-i]=0; res[8][size-1-i]=True
        if not res[size-1-i][8]: m[size-1-i][8]=0; res[size-1-i][8]=True

    if ver>=7:                            # area reservada de versao
        for i in range(6):
            for j in range(3):
                m[size-11+j][i]=0; res[size-11+j][i]=True
                m[i][size-11+j]=0; res[i][size-11+j]=True

    # dados em zigue-zague
    bits=[(cw>>i)&1 for cw in codewords for i in range(7,-1,-1)]
    idx=0; col=size-1; upward=True
    while col > 0:
        if col == 6: col -= 1
        rows = range(size-1,-1,-1) if upward else range(size)
        for row in rows:
            for c in (col, col-1):
                if not res[row][c]:
                    m[row][c] = bits[idx] if idx < len(bits) else 0
                    idx += 1
        upward = not upward; col -= 2
    return m, res

def mask_fn(k, r, c):
    return [ (r+c)%2==0, r%2==0, c%3==0, (r+c)%3==0,
             (r//2 + c//3)%2==0, (r*c)%2 + (r*c)%3 == 0,
             ((r*c)%2 + (r*c)%3)%2==0, ((r+c)%2 + (r*c)%3)%2==0 ][k]

def apply_mask(m,res,k):
    size=len(m)
    out=[row[:] for row in m]
    for r in range(size):
        for c in range(size):
            if not res[r][c] and mask_fn(k,r,c):
                out[r][c] ^= 1
    return out

def bch_format(fmt):
    g=0b10100110111; v=fmt<<10
    for i in range(4,-1,-1):
        if v & (1<<(i+10)): v ^= g<<i
    return ((fmt<<10)|v) ^ 0b101010000010010

def bch_version(ver):
    g=0b1111100100101; v=ver<<12
    for i in range(5,-1,-1):
        if v & (1<<(i+12)): v ^= g<<i
    return (ver<<12)|v

def place_format(m, ecl, mask):
    # Bit i (LSB primeiro). Copia 1: desce a coluna 8 e vira na linha 8.
    # Copia 2: percorre a linha 8 pela direita e desce a coluna 8 no rodape.
    size=len(m)
    bits=bch_format((ECC_BITS[ecl]<<3)|mask)
    for i in range(15):
        b=(bits>>i)&1
        if   i < 6: m[i][8]  = b
        elif i == 6: m[7][8] = b
        elif i == 7: m[8][8] = b
        elif i == 8: m[8][7] = b
        else:        m[8][14-i] = b
        if i < 8: m[8][size-1-i] = b
        else:     m[size-15+i][8] = b
    m[size-8][8]=1

def place_version(m, ver):
    if ver<7: return
    size=len(m); bits=bch_version(ver)
    for i in range(18):
        b=(bits>>i)&1
        r,c = i//3, i%3
        m[size-11+c][r]=b
        m[r][size-11+c]=b

def penalty(m):
    size=len(m); s=0
    for line in list(m)+[list(col) for col in zip(*m)]:
        run=1
        for i in range(1,size):
            if line[i]==line[i-1]: run+=1
            else:
                if run>=5: s += 3+(run-5)
                run=1
        if run>=5: s += 3+(run-5)
    for r in range(size-1):
        for c in range(size-1):
            if m[r][c]==m[r][c+1]==m[r+1][c]==m[r+1][c+1]: s += 3
    pat=[1,0,1,1,1,0,1,0,0,0,0]
    for line in list(m)+[list(col) for col in zip(*m)]:
        for i in range(size-10):
            if line[i:i+11]==pat or line[i:i+11]==pat[::-1]: s += 40
    dark=sum(sum(r) for r in m); total=size*size
    s += 10*(abs(dark*100//total - 50)//5)
    return s

def make_qr(text, ecl='M'):
    data=text.encode('utf-8')
    ver=choose_version(len(data), ecl)
    cws=encode_data(data, ver, ecl)
    base,res=build_matrix(ver, ecl, cws)
    best=None
    for k in range(8):
        cand=apply_mask(base,res,k)
        place_format(cand, ecl, k); place_version(cand, ver)
        p=penalty(cand)
        if best is None or p<best[0]: best=(p,k,cand)
    return best[2], ver, best[1]
