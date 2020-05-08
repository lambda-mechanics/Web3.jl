const Accounts = artifacts.require("Accounts");

module.exports = function(deployer) {
  deployer.deploy(Accounts);
};
