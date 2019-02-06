# Web3.jl

A module for Ethereum connectivity, similar to web3.js.

Parse ABI files, encode/decode ABI data, and make Ethereum [JSON-RPC](https://github.com/ethereum/wiki/wiki/JSON-RPC) calls.

## Structs

* Web3Connection(url): a JSON-RPC connection to an Ethereum node
* Contract(functions, events): A contract's function and event declarations
* FunctionCall(decl, inputs): A call to a function
* FunctionResult(decl, outputs): The outputs of a function call
* Event(decl, parameters): A logged event

## Variables

* contracts: a dictionary of contract-address => Contract structures

## Functions

* readABI(con::Web3Connection, contractname::String, stream::IO): Read an ABI file for a contract
* encodefunctioncall(io::IO, f::ABIFunction, inputs::Array): Encode a call to a function
* encodefunctioncall(io::IOBuffer, f::ABIFunction, inputs::Array): Encode a call to a function, returns buffer data
* encodefunctionresult(io::IO, f::ABIFunction, outputs::Array): Encode the results of a function
* encodefunctionresult(io::IOBuffer, f::ABIFunction, outputs::Array): Encode the results of a function, returns buffer data
* encodeevent(io::IO, e::ABIEvent, inputs::Array): Encode an event
* encodeevent(io::IOBuffer, e::ABIEvent, inputs::Array): Encode an event, returns buffer data
* decodefunctioncall(io::IO, con::Contract): Decode a function call
* decodefunctionresult(io::IO, con::Contract): Decode a function call result
* decodeevent(io::IO, con::Contract): Decode an event in a transaction log

## API Calls

These aren't all filled in yet but see the package source for a simple way to add more...

* clientversion(con::Web3Connection): returns the client version
* eth: eth API
  * eth.gettransactioncount(con::Web3Connection, addr, context): Get transaction count for a given address and context ("latest", "earliest", "pending", or a block number)
  * eth.gettransactionbyhash(con::Web3connection, hash): Get a transaction
* util: util API
  * util.sha3(con::Web3Connection, str::String): get the keccak hash of a string
  * util.keccak(con::Web3Connection, str::String): get the keccak hash of a string
