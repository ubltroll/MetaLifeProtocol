const TestCoinA = artifacts.require("testCoinA");
const MetaMaster = artifacts.require("metaMaster");
const SaleAuction = artifacts.require("saleAuction");
const SalePlain = artifacts.require("salePlain");

module.exports = function (deployer) {
    deployer.deploy(MetaMaster).then(function(){
        return deployer.deploy(SaleAuction, MetaMaster.address);
    }).then(function(instance){
        return deployer.deploy(SalePlain, MetaMaster.address);
    })
};
