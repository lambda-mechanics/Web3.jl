using Web3

#setverbose(true)

dir = dirname(dirname(dirname(@__FILE__)))

contractid = "0x4ED124fcf412C28E4f36790a3A88056a5c44ade2"

connection = Web3Connection("http://localhost:7545")

abifile = reduce(joinpath, split("../contract/build/contracts/Accounts.json", "/")) # platform path

connection, abifile

#contract = readABI(connection, contract, open(abifile))
context = ContractContext(connection, contractid, open(abifile))

println("Signatures...")
for (name, func) in functions(context)
    if isa(name, String)
        println("$name($(join(repr.(func.argtypes), ", ")))")
    end
end

println("Check Client...")
println("clientversion: " * clientversion(connection))
println("netversion: " * net.version(connection))
println("protocolversion: " * eth.protocolversion(connection))
println("gasprice: " * eth.gasprice(connection))
println("blocknumber: " * eth.blocknumber(connection))

# Local Clients
# println("coinbase: " * eth.coinbase(connection))
# println("hashrate: " * eth.hashrate(connection))
# println("syncing: " * eth.syncing(connection))
# println("mining: " * eth.mining(connection))
# println("sha3: " * eth.sha3(connection))
# println("getwork: " * eth.getwork(connection))

# Frequently used RPC methods
println("getbalance: " * eth.getbalance(connection, "0x79F379CebBD362c99Af2765d1fa541415aa78508", "latest"))
println("Transactions: " * eth.gettransactioncount(connection, "0x4083eFF85F0C6a740c440E3419EbE6f7E1713447", "latest"))
println("Latest block transaction count: " * eth.getblocktransactioncountbynumber(connection, "latest"))

# txbyhash = eth.gettransactionbyhash(connection, "0x25b23c0d5edfa8433388bbb3e3ae2f76feed4495038fcbdf376b252c9ede18fd")
# txreceipt = eth.gettransactionreceipt(connection, "0x73b3a1505d4d9cca70d3082d660e7e696f9abf6fc2d1b7c3a35a1699b779e1d4")
# blockbyhash = eth.getblockbyhash(connection, "0x6e89e4ba74265a1ef762095428e7b954b40e2b2085b02e00f837a935f1a13119", true)
# blockbynumber = eth.getblockbynumber(connection, "latest", true)
# accounts = eth.accounts(connection)

println("Wrappers...")
#for p in map(pair-> pair[1] => pair[2], collect(contract(context).functions))
#    println("($(typeof(p[1]))) $(p[1]) => $(repr(first(methods(p[2]))))")
#end

#println(repr(context.numAccounts))

#println(context.numAccounts().send)

println("num accounts: ", context.numAccounts.call().little)
#context.updateAccount.send(true, "d", "e", "f", from = "0x579CDD2D6404f033E70336BDE7a30CDf5c2c574c", gas = 200000)
#println("Account info for bubba: ", context.getAccount.call("d"))

println("done")
