using Web3

dir = dirname(dirname(dirname(@__FILE__)))

contractid = "0xbC0ACbb20C03030308b2FBCAde275Ba1889C37dF"

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

#println(repr(context.numAccounts))

#println(context.numAccounts().send)

println(context.numAccounts().send("0x4083eFF85F0C6a740c440E3419EbE6f7E1713447"))

println("done")
