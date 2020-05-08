const keccakf_rndc = UInt64[0x0000000000000001, 0x0000000000008082, 0x800000000000808a, 0x8000000080008000, 0x000000000000808b, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009, 0x000000000000008a, 0x0000000000000088, 0x0000000080008009, 0x000000008000000a, 0x000000008000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003, 0x8000000000008002, 0x8000000000000080, 0x000000000000800a, 0x800000008000000a, 0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008]
const keccakf_rotc = UInt32[1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44]
const keccakf_piln = map((x)-> x + 1, UInt32[10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1])
const KECCAKF_ROUNDS = 24

@inline rotl64(x, y) = (x << y) | (x >> (64 - y))

mutable struct Ctx
    q::Vector{UInt64}
    b::AbstractArray{UInt8}
    pt::UInt64 # location in b, starts at 1
    rsiz::UInt64
    mdlen::UInt64
    function Ctx(mdlen)
        q = zeros(UInt64, 25)
        new(q, reinterpret(UInt8, q), 1, 200 - 2 * mdlen, mdlen)
    end
end

macro reorderfrom(ctx)
    if reinterpret(UInt8, UInt64[3])[1] == 3
        :()
    else
        :(fromendian($(esc(ctx))))
    end
end

function fromendian(ctx::Ctx)
    offset = 1
    q = ctx.q
    b = ctx.b
    for i in 1:length(ctx.q)
        q[i] = b[offset] | b[offset + 1] << 8 |
          b[offset + 2] << 16 | b[offset + 3] << 24 |
          b[offset + 4] << 32 | b[offset + 5] << 40 |
          b[offset + 6] << 48 | b[offset + 7] << 56
    end
end

macro reorderto(ctx)
    if reinterpret(UInt8, UInt64[3])[1] == 3
        :()
    else
        :(toendian($(esc(ctx))))
    end
end

function toendian(ctx::Ctx)
    q = ctx.q
    b = ctx.b
    for i in 1:length(a)
        offset = (i - 1) * 8 + 1
        t = q[i]
        b[offset] = t & 0xFF
        b[offset + 1] = (t >> 8) & 0xFF
        b[offset + 2] = (t >> 16) & 0xFF
        b[offset + 3] = (t >> 24) & 0xFF
        b[offset + 4] = (t >> 32) & 0xFF
        b[offset + 5] = (t >> 40) & 0xFF
        b[offset + 6] = (t >> 48) & 0xFF
        b[offset + 7] = (t >> 56) & 0xFF
    end
end

function sha3_keccakf(ctx::Ctx)
    i = j = 0
    t::UInt64 = 0
    bc = UInt64[0, 0, 0, 0, 0]
    st = ctx.q

    @reorderfrom(ctx)
    for r in 1:KECCAKF_ROUNDS
        # Theta
        for i in 1:5
            bc[i] = st[i] ⊻ st[i + 5] ⊻ st[i + 10] ⊻ st[i + 15] ⊻ st[i + 20]
        end
        for i in 1:5
            t = bc[(i + 3) % 5 + 1] ⊻ rotl64(bc[i % 5 + 1], 1)
            for j in 1:5:25
                st[j + i - 1] ⊻= t
            end
        end
        # Rho Pi
        t = st[2]
        for i in 1:24
            j = keccakf_piln[i]
            bc[1] = st[j]
            st[j] = rotl64(t, keccakf_rotc[i])
            t = bc[1]
        end
        # Chi
        for j in 1:5:25
            for i in 1:5
                bc[i] = st[j + i - 1]
            end
            for i in 1:5
                st[j + i - 1] ⊻= ~bc[i % 5 + 1] & bc[(i + 1) % 5 + 1]
            end
        end
        # Iota
        st[1] ⊻= keccakf_rndc[r]
    end
    @reorderto(ctx)
end

# Initialize the context for SHA3
const sha3_init = Ctx # alias for sha3_init(mdlen)

# update state with more data
function sha3_update(c::Ctx, data::Vector{UInt8})
    j = c.pt
    for i in 1:length(data)
        c.b[j] ⊻= data[i]
        j += 1
        if j > c.rsiz
            sha3_keccakf(c)
            j = 1
        end
    end
    c.pt = j
end

# finalize and output a hash
function sha3_final(c::Ctx)
    c.b[c.pt] ⊻= 0x06
    c.b[c.rsiz] ⊻= 0x80
    sha3_keccakf(c)
    c.b[1:c.mdlen] # return first mdlen bytes of c.b
end

# compute a SHA-3 hash (md) of given byte length from "in"
function sha3(in::Vector{UInt8}, mdlen::Int64)
    sha3 = Ctx(mdlen)
    sha3_update(sha3, in)
    sha3_final(sha3)
end

# SHAKE128 and SHAKE256 extensible-output functionality

function shake_xof(c::Ctx)
    c.b[c.pt] ⊻= 0x1F
    c.b[c.rsiz] ⊻= 0x80
    sha3_keccakf(c)
    c.pt = 1
end

function shake_out(c::Ctx, out::Vector{UInt8})
    j = c.pt
    for i in 1:length(out)
        if j > c.rsiz
            sha3_keccakf(c)
            j = 1
        end
        out[i] = c.b[j]
        j += 1
    end
    c.pt = j
end

function shake(in::Vector{UInt8}, mdlen::Int64)
    buf = zeros(UInt8, 32)
    c = Ctx(mdlen)

    sha3_update(c, in)
    shake_xof(c)
    for j in 1:32:512
        shake_out(c, buf)
    end
    buf
end

# finalize and output a hash
function keccak_final(c::Ctx)
    c.b[c.pt] ⊻= 0x01
    c.b[c.rsiz] ⊻= 0x80
    sha3_keccakf(c)
    c.b[1:c.mdlen] # return first mdlen bytes of c.b
end

# compute a keccak hash (md) of given byte length from "in"
function keccak(in::Vector{UInt8}, mdlen::Int64)
    sha3 = Ctx(mdlen)
    sha3_update(sha3, in)
    keccak_final(sha3)
end

macro defsha3(bits)
    :($(Symbol("sha3_" * string(bits) * "_init"))() = sha3_init($(UInt(trunc(bits / 8)))))
end

@defsha3(224)
@defsha3(256)
@defsha3(384)
@defsha3(512)

sha3_224(in::Vector{UInt8}) = sha3(in, 28)
sha3_256(in::Vector{UInt8}) = sha3(in, 32)
sha3_384(in::Vector{UInt8}) = sha3(in, 48)
sha3_512(in::Vector{UInt8}) = sha3(in, 64)

keccak224(in::Vector{UInt8}) = keccak(in, 28)
keccak256(in::Vector{UInt8}) = keccak(in, 32)
keccak384(in::Vector{UInt8}) = keccak(in, 48)
keccak512(in::Vector{UInt8}) = keccak(in, 64)

function test()
    println("sha3_224 zero\n  expect: 6B4E03423667DBB73B6E15454F0EB1ABD4597F9A1B078E3F5B5A6BC7\n"
      * "  got:    " * uppercase(bytes2hex(sha3(UInt8[], Int(224/8)))))
    println("sha3_256 zero\n  expect: A7FFC6F8BF1ED76651C14756A061D662F580FF4DE43B49FA82D80A4B80F8434A\n"
      * "  got:    " * uppercase(bytes2hex(sha3(UInt8[], Int(256/8)))))
    println("shake128 zero\n  expect: 43E41B45A653F2A5C4492C1ADD544512DDA2529833462B71A41A45BE97290B6F\n"
      * "  got:    " * uppercase(bytes2hex(shake(UInt8[], 16))))
    println("shake256 zero\n  expect: AB0BAE316339894304E35877B0C28A9B1FD166C796B9CC258A064A8F57E27F2A\n"
      * "  got:    " * uppercase(bytes2hex(shake(UInt8[], 32))))
    println("shake128 1600-bit\n  expect: 44C9FB359FD56AC0A9A75A743CFF6862F17D7259AB075216C0699511643B6439\n"
      * "  got:    " * uppercase(bytes2hex(shake(fill(0xA3, UInt(1600 / 8)), 16))))
    println("shake256 1600-bit\n  expect: 6A1A9D7846436E4DCA5728B6F760EEF0CA92BF0BE5615E96959D767197A0BEEB\n"
      * "  got:    " * uppercase(bytes2hex(shake(fill(0xA3, UInt(1600 / 8)), 32))))
    println("keccak256(hello)\n  expect: 1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8\n"
      * "  got:    " * lowercase(bytes2hex(keccak(collect(UInt8, "hello"), 32))))
    println("keccak256 zero\n  expect: c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470\n"
      * "  got:    " * lowercase(bytes2hex(keccak256(UInt8[]))))
    println("keccak256 2000-bit\n  expect: ???\n"
      * "  got:    " * lowercase(bytes2hex(keccak256(fill(UInt8(0xEF), 2000)))))
end
