using Test, Web3

abi = """[{"constant":false,"inputs":[{"name":"i","type":"int32"}],"name":"add","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}]"""

Web3.hash(hashes::Dict, str::String) = hashes[str]

hashes = Dict([
    "add(int32)" => hex2bytes("57b8a50f")
])

contract = "0x694b0b0853c64aa51ebce186dd27bd676486cb43"

txn = Dict{String,Any}(
    "gasPrice" => "0x4a817c800",
    "r" => "0x9a8d626b553ac295eb6c0cf692e5d88b97c073d40e1093122881073f18180fda",
    "blockNumber" => "0x7",
    "value" => "0x0",
    "gas" => "0x6691b7",
    "s" => "0x6acc9e3f3f04edf65a25fd63681af90fe197c4a16978c2646a3d368573fdf69f",
    "v" => "0x1c",
    "hash" => "0x38f537910e76108cb65807939ca3ed72858e2f8ee4520b58e1c6069a70e9384a",
    "transactionIndex" => "0x0",
    "input" => "0x57b8a50f0000000000000000000000000000000000000000000000000000000000000003",
    "blockHash" => "0x09f1aebdc61f76fc906fd95176f72960f04c72c5da28efd620df60b2169a2829",
    "to" => "0x694b0b0853c64aa51ebce186dd27bd676486cb43",
    "from" => "0xdb810d2557b2e9be3d86ec02e4ea6b4aaa93b7c7",
    "nonce" => "0x6"
)

# install contract
@test readABI(hashes, contract, IOBuffer(abi)) != nothing

# test basic function call
decoded = decodefunctioncall(IOBuffer(hex2bytes(txn["input"][3:end])), contracts[txn["to"]])
data = encodefunctioncall(IOBuffer(UInt8[], write=true), decoded.decl, decoded.inputs)
@test txn["input"] == "0x" * bytes2hex(data)
