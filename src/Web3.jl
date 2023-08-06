"""
    Web3

A module for Ethereum connectivity.

Parse ABI files, encode/decode ABI data, and make JSON-RPC calls.
"""
module Web3

#=
Parse ABI files and encode / decode ABI data

TUPLE AND FIXED LENGTH ARRAY: [fix1 ... fixN][var1 ... varN]
for static types, fixN is the encoded data and varN is empty
for dynamic types, fixN is the length as a uint256 and varN is the encoded data

DYNAMIC ARRAY: [LEN][ARRAY ENCODING...]

UINT<M> and INT<M>: encoded as 32-byte, big-endian values, i.e. as uint256 and int256 numbers

BYTES: [len as uint256][data]

STRING: a bytes representation of the UTF-8 data

ADDRESS: a uint160, encoded as a 32-byte, big-endian value

BOOL: a uint8, encoded as a 32-byte, big-endian value

BYTES<M>: the sequence of bytes, padded with trailing zeroes to a length of 32-bytes

FUNCTION CALL: [4-byte hash][args tuple]
hash is the first 4 high-order bytes of the hash of the signature name(type,type...)

RETURN VALUE: [return tuple]

EVENT: [contract address][topics[0]: signature][topics[n]: indexed args[n - 1]][data -- unindexed args]
topics are 32-bytes; dynamic values are represented as a hash and lose information
=#

using HTTP, JSON, Core

export readABI, Web3Connection, Contract, contracts
export FunctionCall, encodefunctioncall, decodefunctioncall
export FunctionResult, encodefunctionresult, decodefunctionresult
export Event, encodeevent, decodeevent
export clientversion, eth, utils, net, shh, db
export computetypes, ContractContext, contract, connection, functions
export sha3_224, sha3_256, sha3_384, sha3_512
export setverbose
#export keccac224, keccac256, keccac384, keccac512

include("keccak.jl")

# note that msgId is not safe for multi-threaded access
msgId = 1

####################
# Web3
####################

"""
    Web3Connection

A JSON-RPC connection to an Ethereum node

```
    web3 = Web3Connection("http://localhost:8545")
    clientversion(web3) # -- return the client version
    jsonget("http://localhost:8545", :web3_clientVersion, []) # -- equivalent to clientversion(web3)
    rawjsonget("http://localhost:8545", :web3_clientVersion, []) # -- return full JSON object
```
"""
struct Web3Connection
    url
end

"""
    jsonget(url, methodname, params...)

Call a JSON-RPC method and return the result property of the JSON result
"""
#jsonget(url, method, params...) = rawjsonget(url, method, params...)["result"]
function jsonget(url, method, params...)
    json = rawjsonget(url, method, params...)
    if verbose println("JSON: ", repr(json)) end
    if haskey(json, "result")
        json["result"]
    elseif haskey(json, "error")
        throw(ErrorException(json["error"]["message"]))
    else
        throw(ErrorException("Bad JSON response, no error or result: $(repr(json))"))
    end
end

"""
    rawjsonget(url, method, params...)

Call a JSON-RPC method and return the full JSON result
"""
function rawjsonget(url, method, params...)
    req = JSON.json(Dict([
        :jsonrpc => "2.0"
        :method => method
        :params => params
        :id => (global msgId += 1)
    ]))
    if verbose println("\nREQUEST: $(req)\n") end
    headers = ["Content-Type" => "application/json"]
    resp = HTTP.request("POST", url, headers, req)
    if resp.status == 200
        resultstr = String(resp.body)
        result = JSON.parse(resultstr)
        if verbose
            println("RESULT JSON: $resultstr")
            println("RESULT: $(repr(result))")
        end
        result
    else
        throw(ErrorException("Error, status = $(resp.status)"))
    end
end

"""
    apifunc

Create a call to an API func, given a function that converts inputs to JSON-ready inputs
"""
apifunc(apimethod, func) = (con::Web3Connection, args...; raw=false)-> (raw ? rawjsonget : jsonget)(con.url, apimethod, func(args...)...)

function hash end

const clientversion = apifunc(:web3_clientVersion, ()-> ())

const net = (
    version = apifunc(:net_version, ()-> ()),
    peercount = apifunc(:net_peerCount, ()-> ()),
    listening = apifunc(:net_listening, ()-> ()),
)

const eth = (
    protocolversion = apifunc(:eth_protocolVersion, ()-> ()),
    syncing = apifunc(:eth_syncing, ()-> ()),
    mining = apifunc(:eth_mining, ()-> ()),
    coinbase = apifunc(:eth_coinbase, ()-> ()),
    hashrate = apifunc(:eth_hashrate, ()-> ()),
    accounts = apifunc(:eth_accounts, ()-> ()),
    gasprice = apifunc(:eth_gasPrice, ()-> ()),
    blocknumber = apifunc(:eth_blockNumber, ()-> ()),
    getbalance = apifunc(:eth_getBalance, (addr, ctx)-> (addr, ctx)),
    getstorageat = apifunc(:eth_getStorageAt, (addr, pos, ctx)-> (addr, pos, ctx)),
    getcode = apifunc(:eth_getCode, (addr, ctx)-> (addr, ctx)),
    gettransactioncount = apifunc(:eth_getTransactionCount, (addr, ctx)-> (addr, ctx)),
    getblocktransactioncountbyhash = apifunc(:eth_getBlockTransactionCountByHash, (hash)-> (hash,)),
    getblocktransactioncountbynumber = apifunc(:eth_getBlockTransactionCountByNumber, (tag)-> (tag,)),
    getblockbyhash = apifunc(:eth_getBlockByHash, (hash, ctx)-> (hash, ctx)),
    getblockbynumber = apifunc(:eth_getBlockByNumber, (tag, ctx)-> (tag, ctx)),
    gettransactionbyhash = apifunc(:eth_getTransactionByHash, (hash)-> (hash,)),
    gettransactionreceipt = apifunc(:eth_getTransactionReceipt, (hash)-> (hash,)),
    gettransactionbyblockhashandindex = apifunc(:eth_getTransactionByBlockHashAndIndex, (hash, index)-> (hash, index)),
    gettransactionbyblocknumberandindex = apifunc(:eth_getTransactionByBlockNumberAndIndex, (tag, index)-> (tag, index)),
    getunclecountbyblockhash = apifunc(:eth_getUncleCountByBlockHash, (hash)-> (hash,)),
    getunclecountbyblocknumber = apifunc(:eth_getUncleCountByBlockNumber, (tag)-> (tag,)),
    getunclebyblockhashandindex = apifunc(:eth_getUncleByBlockHashAndIndex, (hash, index)-> (hash, index)),
    getunclebyblocknumberandindex = apifunc(:eth_getUncleByBlockNumberAndIndex, (tag, index)-> (tag, index)),
    estimategas = apifunc(:eth_estimateGas, (dict)-> dict),
    call = apifunc(:eth_call, (dict)-> dict),
    sendtransaction = apifunc(:eth_sendTransaction, (from, to, gas, gasprice, value, data, nonce)->
                              Dict([:from => from
                                    :to => to
                                    :gas => gas
                                    :gasprice => gasprice
                                    :value => value
                                    :data => data
                                    :nonce => nonce])),
    sign = apifunc(:eth_sign, (address, data)-> (address, data)),
    sendrawtransaction = apifunc(:eth_sendRawTransaction, (data)-> (data,)),
    pendingtransactions = apifunc(:eth_pendingTransactions, ()-> ()),
    newfilter = apifunc(:eth_newFilter, (fromBlock, toBlock, address, topics)->
                              Dict([:fromBlock => fromBlock
                                    :toBlock => toBlock
                                    :address => address
                                    :topics => topics])),
    newblockfilter = apifunc(:eth_newBlockFilter, ()-> ()),
    newpendingtransactionfilter = apifunc(:eth_newPendingTransactionFilter, ()-> ()),
    uninstallfilter = apifunc(:eth_uninstallFilter, (filterid)-> (filterid,)),
    getfilterchanges = apifunc(:eth_getFilterChanges, (filterid)-> (filterid,)),
    getfilterlogs = apifunc(:eth_getFilterLogs, (filterid)-> (filterid,)),
    getlogs = apifunc(:eth_getLogs, (fromBlock, toBlock, address, topics, blockhash)->
                              Dict([:fromBlock => fromBlock
                                    :toBlock => toBlock
                                    :address => address
                                    :topics => topics
                                    :blockhash => blockhash])),
    getwork = apifunc(:eth_getWork, ()-> ()),
    submitwork = apifunc(:eth_submitWork, (nonce, powhash, mixdigest)-> (nonce, powhash, mixdigest)),
    submithashrate = apifunc(:eth_submitHashrate, (hashrate, id)-> (hashrate, id)),
    getproof = apifunc(:eth_getProof, (address, keys, blocktag)-> (address, keys, blocktag)),
)

const db = (
    putstring = apifunc(:db_putString, (db, key, value)-> (db, key, value,)),
    getstring = apifunc(:db_getString, (db, key)-> (value,)),
    puthex = apifunc(:db_putHex, (db, key, value)-> (db, key, value,)),
    gethex = apifunc(:db_getHex, (db, key)-> (value,)),
)

const shh = (
    version = apifunc(:shh_version, ()-> ()),
    post = apifunc(:shh_post, (from, to, topics, payload, priority, ttl)->
                              Dict([:from => from
                                    :to => to
                                    :topics => topics
                                    :payload => payload
                                    :priority => priority
                                    :ttl => ttl])),
    newidentity = apifunc(:shh_newIdentity, ()-> ()),
    hasidentity = apifunc(:shh_hasIdentity, (identity)-> (identity,)),
    newgroup = apifunc(:shh_newGroup, ()-> ()),
    addtogroup = apifunc(:shh_addToGroup, (identity)-> (identity,)),
    newfilter = apifunc(:shh_newFilter, (to, topics)->
                              Dict([:to => to
                                    :topics => topics])),
    uninstallfilter = apifunc(:shh_uninstallFilter, (filterid)-> (filterid,)),
    getfilterchanges = apifunc(:shh_getFilterChanges, (filterid)-> (filterid,)),
    getmessages = apifunc(:shh_getMessages, (filterid)-> (filterid,)),
)

const utils = (
    keccak = hash,
)

# This is a separate function so that test code can override it
function hash(con::Web3Connection, str::String)
    #hex2bytes(jsonget(con.url, :web3_sha3, ("0x" * bytes2hex(Vector{UInt8}(str))))[3:end])
    keccak256(collect(UInt8, str))
end

"""
    resultbytes

Convert a JSON-RPC API call result to bytes
"""
resultbytes(func) = (args...)-> hex2bytes(func(args...)[3:end])

####################
# ABI
####################

## Int256 and UInt256 should be changed to primitive types
## See https://github.com/rfourquet/BitIntegers2.jl/blob/master/src/BitIntegers.jl

struct Int256
    big::Int128
    little::UInt128
    Int256(i::Integer) = new(i < 0 ? -1 : 0, i)
    Int256(big::Integer, little::Unsigned) = new(big, little)
end

struct UInt256
    big::UInt128
    little::UInt128
    UInt256(i::Unsigned) = new(0, i)
    UInt256(big::Unsigned, little::Unsigned) = new(big, little)
end

struct ABIType{T}
    ABIType(arg) = new{arg}()
end

struct Decl{ENCMODE, X, Y, Z}
    name::String
    typename::String
    components::Array
    indexed::Bool
end

struct ABIFunction
    constant
    hash # first 4 bytes of keccak hash
    inputs::Array{Decl}
    name
    outputs
    payable
    signature
    statemutability
    argtypes
end

struct ABIEvent
    name
    hash
    signature
    anonymous
    inputs::Array{Decl}
end

struct FunctionCall
    decl
    inputs::Array
end

struct FunctionResult
    decl
    result
end

struct Event
    decl
    parameters::Array
end

struct Contract{Name}
    id::String
    functions
    events
    function Contract(id::String)
        id = cleanaddress(id)
        new{Symbol(id)}(id, Dict{Union{String, Vector{UInt8}}, ABIFunction}(), Dict())
    end
end

function cleanaddress(str::String)
    if match(r"^0[xX]", str) != nothing
        str = str[3:end]
    end
    @assert match(r"[0-9a-fA-F]{20}", str) != nothing
    str
end

const NumDecl = Union{Decl{T, :int} where T, Decl{T, :uint} where T}
const FunctionABI = Union{ABIType{:function}, ABIType{:constructor}, ABIType{:fallback}};

"A dictionary of contract-address => Contract structures"
const contracts = Dict()

const fixedarraypattern = r".*\[([^\]]+)\]"
const bitspattern = r"^([^[0-9]+)([0-9]*)"

##############
# ENCODING
##############

"""
    encodefunctioncall(f::ABIFunction, inputs::Array) -> data
    encodefunctioncall(io::IO, f::ABIFunction, inputs::Array)
    encodefunctioncall(io::IOBuffer, f::ABIFunction, inputs::Array) -> data

Encode a call to a function
"""
encodefunctioncall(f::ABIFunction, inputs::Array) = encodefunctioncall(IOBuffer(), f, inputs)
encodefunctioncall(io::IO, f::ABIFunction, inputs::Array) = basicencodefunctioncall(io, f, inputs)
function encodefunctioncall(io::IOBuffer, f::ABIFunction, inputs::Array)
    basicencodefunctioncall(io, f, inputs)
    take!(io)
end

function basicencodefunctioncall(io::IO, f::ABIFunction, inputs::Array)
    if length(f.inputs) != length(inputs)
        throw("Wrong number of inputs to $(f.name), expecting $(length(f.inputs)) but got $(length(inputs))")
    end
    write(io, f.hash)
    encode(io, f.inputs, inputs)
end

"""
    encodefunctionresult(io::IO, f::ABIFunction, outputs::Array)

Encode the results of a function
"""
function encodefunctionresult(io::IO, f::ABIFunction, outputs::Array)
    basicencodefunctionresult(io, f, outputs)
end

function encodefunctionresult(io::IOBuffer, f::ABIFunction, outputs::Array)
    basicencodefunctionresult(io, f, outputs)
    io.data
end

function basicencodefunctionresult(io::IO, f::ABIFunction, outputs::Array)
    write(io, f.hash)
    encode(io, f.outputs, outputs)
end

"""
    encodeevent(io::IO, e::ABIEvent, inputs::Array)

Encode an event
"""
function encodeevent(io::IO, e::ABIEvent, inputs::Array)
    basicencodeevent(io, e, inputs)
end

function encodeevent(io::IOBuffer, e::ABIEvent, inputs::Array)
    basicencodeevent(io, e, inputs)
    io.data
end

function basicencodeevent(io::IO, e::ABIEvent, inputs::Array)
    write(io, e.hash)
    encode(io, e.inputs, inputs)
end

function encode(io::IO, decl::Union{Decl, Array}, value)
    encodehead(io, decl, value, length(value) * 32)
    encodetail(io, decl, value)
end

encint(io, i::Signed) = encints(Int128(i < 0 ? -1 : 0), Int128(i))
encint(io, i::Unsigned) = encints(io, UInt128(0), UInt128(i))
encint(io, i::Union{Int256, UInt256}) = encints(i.big, i.little)
encints(io, ints...) = vcat(hton.(ints)...)

# utilities
writeint(io, i::Signed) = writeints(io, Int128(i < 0 ? -1 : 0), Int128(i))
writeint(io, i::Unsigned) = writeints(io, UInt128(0), UInt128(i))
writeint(io, i::Union{Int256, UInt256}) = writeints(io, i.big, i.little)
writeints(io, ints...) = write(io, hton.(ints)...)
encodescalar(io::IO, decl::Decl{:scalar, :bool}, value) = writeint(io, value ? 1 : 0)
encodescalar(io::IO, decl::NumDecl, value) = writeint(io, value)

# scalar types
function encodehead(io::IO, decl::Decl{:scalar}, v, offset::Int)
    encodescalar(io, decl, v)
    offset
end
encodetail(io, ::Decl{:scalar}, v) = nothing

# dynamic types
function encodehead(io::IO, ::Union{Decl{:string}, Decl{:bytes}}, v, offset::Int)::Int
    writeint(io, offset)
    offset + ceil(length(IOBuffer(v).data) / 32) * 32 + 32
end
function encodetail(io, ::Union{Decl{:string}, Decl{:bytes}}, v)
    buf = IOBuffer(v)
    len = bytesavailable(buf)
    writeint(io, len)
    write(io, v)
    pad = 32 - len % 32
    if pad != 32
        for i = 1 : pad
            write(io, Int8(0))
        end
    end
end
function encodehead(io::IO, ::Decl{:dynamic}, v, offset::Int)
    writeint(io, offset)
    offset + length(v) * 64
end
function encodetail(io::IO, decl::Decl{:dynamic}, values)
    for v in values
        encodescalar(decl, v)
    end
end

# fixed-size array
function encodehead(io::IO, decl::Decl{:array, BASE, BITS, LENGTH}, values, offset::Int) where {BASE, BITS, LENGTH}
    writeint(io, offset)
    offset + LENGTH * 64
end
function encodetail(io::IO, decl::Decl{:array, BASE, BITS, LENGTH}, values) where {BASE, BITS, LENGTH}
    t = arraycomptype(decl)
    writeint(length)
    offset = 0
    for i in 1:LENGTH
        offset = encodehead(io, t, values[i], offset)
    end
end
function arraycomptype(decl::Decl{:array, BASE, BITS, LENGTH}) where {BASE, BITS, LENGTH}
    if decl.components != nothing
        Decl{:tuple, length(decl.components), :n, :n}(decl.name, "tuple", decl.components, false)
    else
        Decl{:scalar, BASE, BITS, :none}(decl.name, decl.typename, :nothing, false)
    end
end

# tuple
encodehead(io::IO, decl::Decl{:tuple}, values, offset) = encodehead(io, decl.components, values, offset)
encodetail(io::IO, decl::Decl{:tuple}, values) = encodetail(io, decl.components, values)
function encodehead(io::IO, decls::Array{Decl}, values, offset::Int)
    for i in 1:length(decls)
        offset = encodehead(io, decls[i], values[i], offset)
    end
    offset
end
function encodetail(io::IO, decls::Array{Decl}, values)
    for i in 1:length(decls)
        encodetail(io, decls[i], values[i])
    end
end

############
# DECODING
############

const signedTypes = Dict([sizeof(t) => t for t in (Int8, Int16, Int32, Int64, Int128)])
const unsignedTypes = Dict([sizeof(t) => t for t in (UInt8, UInt16, UInt32, UInt64, UInt128)])

function readint(io::IO)
    big = read(io, Int128)
    Int256(ntoh(big), ntoh(read(io, UInt128)))
end

function readuint(io::IO)
    big = read(io, UInt128)
    Int256(ntoh(big), ntoh(read(io, UInt128)))
end

readlength(io::IO) = (read(io, UInt128);ntoh(read(io, UInt128)))

"""
    decodefunctioncall(io::IO, con::Contract)

Decode a function call
"""
function decodefunctioncall(io::IO, con::Contract)
    decl = con.functions[read(io, 4)]
    FunctionCall(decl, decode(io, decl.inputs))
end

"""
    decodefunctionresult(io::IO, con::Contract)

Decode a function call result
"""
function decodefunctionresult(io::IO, con::Contract)
    hash = read(io, 4)
    f = con.functions[hash]
    FunctionResult(f, decode(io, f.outputs))
end

"""
    decodeevent(io::IO, con::Contract)

Decode an event in a transaction log
"""
function decodeevent(io::IO, con::Contract)
    decl = con.events[read(io, 4)]
    Event(decl, decode(io, decl.inputs))
end

# general
decode(io::IO, decl) = decodetail(io, decl, decodehead(io, decl))

# scalar types
decodehead(io::IO, decl::Decl{:scalar}) = decodescalar(io, decl)
decodetail(io::IO, ::Decl{:scalar}, head) = head
function decodescalar(io::IO, ::Decl{T, :int, SIZE}) where {T, SIZE}
    big = ntoh(read(io, Int128))
    little = ntoh(read(io, UInt128))
    SIZE <= 128 ? smallint(SIZE, big < 0 ? -little : little) : Int256(big, little)
end
function decodescalar(io::IO, ::Decl{T, :uint, SIZE}) where {T, SIZE}
    big = ntoh(read(io, UInt128))
    little = ntoh(read(io, UInt128))
    SIZE <= 128 ? smalluint(SIZE, little) : UInt256(big, little)
end

smallint(size, value) = signedTypes[Int(2^ceil(log2(floor((33 + 7) / 8))))](value)
smalulint(size, value) = unsignedTypes[Int(2^ceil(log2(floor((33 + 7) / 8))))](value)

function decode(io::IO, ::Decl{T, :bool}) where T
    big = read(io, UInt128)
    little = read(io, UInt128)
    litle == 0 ? false : true
end

# dynamic types
decodehead(io::IO, decl::Decl{:dynamic, :bytes}) = readlength(io)
decodetail(io::IO, decl::Decl{:dynamic, :bytes}, head) = readbytes(io, head)
readbytes(io::IO, len) = read(io, len)

function decode(io::IO, decl::Decl{:string})
    if verbose println("Reading string at $(position(io))") end
    offset = readlength(io)
    pos = position(io)
    if verbose println("Offset: $(offset)") end
    seek(io, offset)
    count = readlength(io)
    if verbose println("Length: $(count)") end
    result = String(read(io, count))
    seek(io, pos)
    result
end

# array types
function decode(io::IO, decl::Decl{:array, BASE, BITS, LENGTH}) where {BASE, BITS, LENGTH}
    [decodescalar(io, decl) for i in 1:LENGTH]
end
function decode(io::IO, ::Decl{:array, :bytes, BITS, LENGTH}) where {BITS, LENGTH}
    lens = [readlength(io) for i in 1:LENGTH]
    [readbytes(io, len) for len in lens]
end
function decode(io::IO, ::Decl{:array, :string, BITS, LENGTH}) where {BITS, LENGTH}
    lens = [readlength(io) for i in 1:LENGTH]
    [String(readbytes(io, len)) for len in lens]
end
function decode(io::IO, decl::Decl{:array, :tuple, BITS, LENGTH}) where {BITS, LENGTH}
    decodetail(io::IO, decl.components, decodehead(io::IO, decl.components))
end

# tuple
decode(io::IO, decl::Decl{:tuple}) = decodetail(io, decl.components)
#decode(io::IO, decls::Array) = decodetail(io, decls, decodehead(io, decls))
#decodehead(io::IO, decls::Array) = [decodehead(io, head) for head in decls]
#decodetail(io::IO, decls::Array, heads) = [decodetail(io, decls[i], heads[i]) for i in 1:length(decls)]
function decode(io::IO, decls::Array)
    result = []
    for decl in decls
        push!(result, decode(io, decl))
    end
    result
end

####################
# DECL PARSING
####################

rows(array) = [array[row, :] for row in 1:size(a)[1]]

# Make conversion mapping given specs:
#   (Solidity-prefix, Julia type, byte length)
conversions(rows) = vcat([["$stype$(bytes * 8)" => jtype for bytes in rng] for (stype, jtype, rng) in rows]...)

const soliditytojulia = Dict(conversions([
    # Solidity-prefix, Julia type, bytes
    ("int", Int8, [8])
    ("uint", UInt8, [8])
    ("int", Int16, [16])
    ("uint", UInt16, [16])
    ("int", Int32, 3:4)
    ("uint", UInt32, 3:4)
    ("int", Int64, 5:8)
    ("uint", UInt64, 5:8)
    ("int", Int128, 9:16)
    ("uint", UInt128, 9:16)
    ("int", BigInt, 17:32)
    ("uint", BigInt, 17:32)
]))

parseABI(connection::Web3Connection, json) = parseABI(connection, ABIType(Symbol(get(json, "type", "function"))), json)
function parseABI(connection::Web3Connection, ::FunctionABI, func)
    name = func["name"]
    args = join((arg-> arg["type"]).(func["inputs"]), ",")
    sig = "$name($args)"
    inputs = parseargs(func["inputs"])
    if length(func["inputs"]) === 0
        inputs = Decl[]
    end

    ABIFunction(
        func["constant"],
        utils.keccak(connection, sig)[1:4],
        inputs,
        name,
        haskey(func, "outputs") ? parseargs(func["outputs"]) : [],
        func["payable"],
        sig,
        func["stateMutability"],
        computetypes(name, inputs)
    )
end

function parseABI(connection::Web3Connection, ::ABIType{:event}, evt)
    name = evt["name"]
    args = join((arg-> arg["type"]).(evt["inputs"]), ",")
    sig = "$name($args)"
    ABIEvent(evt["name"], utils.keccak(connection, sig)[1:4], sig, get(evt, "anonymous", false), parseargs(evt["inputs"]))
end

computetype(decl::Decl{T, :int, SIZE}) where {T, SIZE} = soliditytojulia["int$SIZE"]
computetype(decl::Decl{T, :uint, SIZE}) where {T, SIZE} = soliditytojulia["uint$SIZE"]
computetype(decl::Decl{:tuple, SIZE}) where {T, SIZE} = "tuple[$SIZE]"
computetype(decl::Decl{:array, BASE, BITS, LENGTH}) where {BASE, BITS, LENGTH} = "array[LENGTH] of $BASE"
computetype(decl::Decl{T, :bool} where {T}) = Bool
computetype(decl::Decl{:string}) = String
computetype(decl::Decl{:bytes}) = Vector{UInt8}
computetype(decl::Decl{:dynamic, TYPE}) where TYPE = "array of $TYPE"

computetypes(func::ABIFunction) = computetypes(func.name, func.inputs)
function computetypes(name, decls::Array{T} where T <: Decl)
    computetype.(decls)
end

"""
    readABI(con::Web3Connection, contractname::String, stream::IO)

Read an ABI file for a contract
"""
function readABI(connection::Web3Connection, contractname::String, stream::IO)
    contract = Contract(contractname)
    d = JSON.parse(stream)
    close(stream)
    d = ((isa(d, Dict) && haskey(d, "abi")) ? d["abi"] : d)
    for json in d
        json = Dict(json)
        obj = parseABI(connection, json)
        if isa(obj, ABIFunction)
            contract.functions[obj.name] = contract.functions[obj.hash] = obj
            if verbose
                println("$(bytes2hex(obj.hash)) $(obj.signature) $(repr(obj)) $(bytes2hex(utils.keccak(connection, obj.signature)))")
            end
        elseif isa(obj, ABIEvent)
            contract.events[obj.name] = contract.events[obj.hash] = obj
            if verbose
                println("$(bytes2hex(obj.hash)) $(obj.signature) $(repr(obj)) $(bytes2hex(utils.keccak(connection, obj.signature)))")
            end
        elseif verbose
            println(repr(obj))
        end
    end
    contracts[contractname] = contract
end

function basetypefor(typename)
    m = match(bitspattern, typename)
    (Symbol(m[1]), m[2] == "" ? 256 : parse(Int, m[2]))
end

function typefor(typename, arg)
    atype = arg["type"]
    if endswith(atype, "[]")
        (:dynamic, basetypefor(typename)..., :none)
    elseif endswith(atype, "]")
        m = match(fixedarraypattern, typename)
        (:array, basetypefor(typename)..., parse(Int, m[1]))
    elseif atype == "tuple"
        (:tuple, length(arg["components"]), :none, :none)
    elseif atype in ["string", "bytes"]
        (Symbol(atype), :none, :none, :none)
    else
        (:scalar, basetypefor(typename)..., :none)
    end
end

function parsearg(arg)
    typename = arg["type"]
    (enctype, atype, bits, len) = typefor(typename, arg)
    Decl{enctype, atype, bits, len}(
        arg["name"],
        typename,
        haskey(arg, "components") ? parseargs(arg["components"]) : [],
        get(arg, "indexed", false)
    )
end

parseargs(args) = parsearg.(args)

####################
# UTILS
####################

global verbose = false

struct ContractContext{contractid}
    connection
    contract
end

connection(con::ContractContext) = getfield(con, :connection)

contract(con::ContractContext) = getfield(con, :contract)

functions(con::ContractContext) = contract(con).functions

struct Val{Name} end

function gen(contract, con)
    funcs = collect(filter(p-> isa(p[1], String), contract.functions))
    funcdict = Dict(map(funcs) do ((name, func)) name => func end)
    methods = map(funcs) do ((name, func))
        argnames = map(a-> Symbol("a$a"), 1:length(func.argtypes))
        args = map(((name, type)::Tuple)-> :($name::$type), zip(argnames, func.argtypes))
        method = :($(Symbol(name)) = (
            send = ($(args...),; options...)-> send(context, $name, [$(argnames...)]; options...),
            call = ($(args...),; options...)-> call(context, $name, [$(argnames...)]; options...),
            estimategas = ($(args...),; options...)-> (),
            encodeabi = ($(args...),; options...)-> begin
                buf = IOBuffer()
                encodefunctioncall(buf, contract(context).functions[$(String(name))], [$(argnames...)])
                take!(buf)
            end
        ))
        if verbose println("\n$name = ", method, "\n") end
        method
    end
    type = ContractContext{Symbol(contract.id)}
    eval(:(Base.getproperty(context::$type, prop::Symbol) = ($(methods...),)[prop]))
end

"""
    send(id, data; options)

options are: gasprice, gas, value, nonce, chain, hardfork, common
"""
function send(context::ContractContext, name, args; options...)
    func = contract(context).functions[name]
    extractresult(func, basicsend(:eth_sendTransaction, context, name, args; options...))
end

function call(context::ContractContext, name, args; options...)
    func = contract(context).functions[name]
    extractresult(func, basicsend(:eth_call, context, name, args; options...))
end

function extractresult(func::ABIFunction, json::Dict)
    if haskey(json, "result")
        if verbose println("DECODING RESULT: ", json["result"]) end
        result = decode(IOBuffer(hex2bytes(json["result"][3:end])), func.outputs)
        if length(result) == 1
            result[1]
        else
            (result...,)
        end
    elseif haskey(json, "error")
        throw(json["error"])
    else
        throw("Unknown result: $(repr(json))")
    end
end

function basicsend(op, context::ContractContext, name, args; options...)
    #println("Call $name in contract $(contract(context).id)\nfrom account $(from)")
    transaction = merge!(Dict([
        :to => lowercase("0x" * contract(context).id)
        :data=> "0x" * bytes2hex(encodefunctioncall(contract(context).functions[name], args)) #encodearguments(args)
        :id => 1
    ]),
                         pairs(options))
    if verbose println(op, " $name DATA: ", transaction[:data]) end
    result = if op == :eth_sendTransaction
        rawjsonget(connection(context).url, op, transaction)
    else
        rawjsonget(connection(context).url, op, transaction, "latest")
    end
    if haskey(result, "error")
        err = result["error"]
        if verbose println("ERROR: $(err["message"])\n$(err["data"]["stack"])") end
    end
    if verbose println(op, " $name RESULT JSON: $(repr(result))") end
    result
end

encodearguments(args) = if args == () "" else :ENCODED_ARGUMENTS end

function ContractContext(url::String, contractid::String, jsonabifile::String)
    ContractContext(Web3Connection(url), contractid, jsonabifile)
end
ContractContext(con::Web3Connection, contractid::String, jsonabifile::String) = ContractContext(con, contractid, open(jsonabifile))

function ContractContext(con::Web3Connection, contractid::String, file::IO)
    contract = readABI(con, contractid, file)
    gen(contract, con)
    ContractContext{Symbol(contract.id)}(con, contract)
end

function setverbose(v)
    global verbose
    verbose = v
end


end # module
