using Web3

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

println("Wrappers...")
#for p in map(pair-> pair[1] => pair[2], collect(contract(context).functions))
#    println("($(typeof(p[1]))) $(p[1]) => $(repr(first(methods(p[2]))))")
#end

println("Transactions: " * eth.gettransactioncount(connection, "0x4083eFF85F0C6a740c440E3419EbE6f7E1713447", "latest"))

#println(repr(context.numAccounts))

#println(context.numAccounts().send)

setverbose(true)

#println(bytes2hex(context.numAccounts().encodeabi()))
#println(context.numAccounts.call(from = "0x4083eFF85F0C6a740c440E3419EbE6f7E1713447"))
println(context.numAccounts.call())

#context.updateAccount

println("done")
