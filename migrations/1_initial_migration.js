// const Migrations = artifacts.require("Migrations");
const Metablox = artifacts.require("Metablox");
const Marketplace = artifacts.require("Marketplace");

module.exports = function (deployer) {
  deployer.deploy(Metablox);
  deployer.deploy(Marketplace);
};
