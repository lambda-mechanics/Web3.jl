pragma solidity >=0.4.25 <0.6.0;

contract Accounts {
  mapping (bytes32 => Account) accounts;
  bytes32[] keys;
  string test2;

  struct Account {
    string id;
    string password;
    string name;
  }

  function numAccounts() public view returns (uint) {
    return keys.length;
  }
  function updateAccount(bool create, string memory id, string memory password, string memory name) public {
    bytes32 hash = keccak256(bytes(id));

    assert(create ? !exists(hash) : exists(hash));
    accounts[hash] = Account(id, password, name);
    if (create) {
      keys.push(hash);
    }
  }
  function deleteAccount(string memory id) public {
    bytes32 hash = keccak256(bytes(id));

    assert(exists(hash));
    delete accounts[hash];
    for (uint i = 0; i < keys.length; i++) {
      if (keys[i] == hash) {
        keys[i] = keys[keys.length - 1];
        keys.pop();
      }
    }
  }
  function accountAt(uint index) public view returns (string memory password, string memory name) {
    Account storage acct = accountForHash(keys[index], true);

    return (acct.password, acct.name);
  }
  function getAccount(string memory id) public view returns (string memory password, string memory name) {
    Account storage acct = account(id, true);

    return (acct.password, acct.name);
  }
  function exists(bytes32 hash) internal view returns (bool) {
    return bytes(accounts[hash].id).length > 0;
  }
  function account(string memory id, bool mustExist) internal view returns (Account storage) {
    return accountForHash(keccak256(bytes(id)), mustExist);
  }
  function accountForHash(bytes32 hash, bool mustExist) internal view returns (Account storage) {
    Account storage acct = accounts[hash];

    assert(mustExist ? exists(hash) : !exists(hash));
    return acct;
  }
}
