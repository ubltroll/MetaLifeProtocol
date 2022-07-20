const TestCoinA = artifacts.require("testCoinA");
const MetaMaster = artifacts.require("metaMaster");
const SaleAuction = artifacts.require("saleAuction");
const SalePlain = artifacts.require("salePlain");
const NFTCollection = artifacts.require("NFTCollection");

function timeout(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

contract('metaMeta', (accounts) => {
    zero_address = "0x0000000000000000000000000000000000000000";
    let testCoinA, master, salePlain, saleAuction;
    let collection_address;
    it('should be configed properly', async () =>{
        if(!testCoinA) testCoinA = await TestCoinA.new();
        master = await MetaMaster.deployed();
        salePlain = await SalePlain.deployed();
        saleAuction = await SaleAuction.deployed();
        assert.equal(await master.owner.call(), accounts[0]);
        //config market
        master.addMarketSale(salePlain.address, { from: accounts[0]});
        master.addMarketSale(saleAuction.address, { from: accounts[0]});
        assert.equal(await master.marketSalesNum.call(), 2);
        assert.equal(await master.marketSales.call(0), salePlain.address);
        assert.equal(await master.marketSales.call(1), saleAuction.address);
        //config token support
        assert.equal(await master.tokenIsSupported.call(testCoinA.address), false);
        master.setTokenSupport(testCoinA.address, { from: accounts[0]});
        assert.equal(await master.tokenIsSupported.call(testCoinA.address), true);
    });
    it('should mint NFTs in collection', async () =>{
        await master.createCollection(
            'TestNFT', 'test', 'http://test.network/', 888, 'descript',
            accounts[1], 750,
            { from: accounts[1]});
        collection_address = await master.userOwnedCollections.call(accounts[1], 0);
        assert.equal(await master.userOwnedCollectionNum.call(accounts[1]), 1);
        assert.equal(await master.collectionOwner.call(collection_address), accounts[1]);
        collection = await NFTCollection.at(collection_address);
        assert.equal(await collection.metaInfo.call(), 'descript');
        assert.equal(await collection.royaltiesPercentageInBips.call(), 750);
        await master.setCollectionMetaInfo(collection_address, 'test', { from: accounts[1]});
        await master.setCollectionRoyalty(collection_address, accounts[5], 750, { from: accounts[1]});
        assert.equal(await collection.metaInfo.call(), 'test');
        //mint NFT 1
        await master.mint(collection_address, accounts[1], 'nft1', { from: accounts[1]});
        assert.equal(await collection.totalSupply.call(), 1);
        assert.equal(await collection.ownerOf.call(1), accounts[1]);
        assert.equal(await collection.tokenURI.call(1), 'http://test.network/nft1');
        assert.equal(await collection.owner.call(), master.address);
    });
    it('should sell NFt at fix price', async () =>{
        assert.equal(await collection.owner.call(), master.address);
        //sell NFT 1
        await master.sell(collection_address, 1, 0, zero_address, 10000, 5000, {from: accounts[1]});
        assert.equal(await collection.ownerOf.call(1), salePlain.address);
        sale_info = await salePlain.getSaleInfo.call(collection_address, 1);
        assert.equal(sale_info[0], true);
        assert.equal(await master.getSalesCount.call(), 1);
        res = await master.getSales.call(5,0);
        assert.equal(res[0].seller, accounts[1]);
        assert.equal(await master.getSalesCountByUser.call(accounts[0]), 0);
        assert.equal(await master.getSalesCountByUser.call(accounts[1]), 1);
        sale_id_nft1 = await salePlain.getSaleId.call(collection_address, 1);
        await salePlain.updatePrice(sale_id_nft1, zero_address, 100000, {from: accounts[1]});
        await salePlain.updateDuration(sale_id_nft1, 5000, {from: accounts[1]});
        assert.equal(await master.feeCollector.call(), accounts[0]);
        assert.equal(await collection.royaltiesReceiver.call(), accounts[5]);
        //buy NFT 1
        await salePlain.bidWithValue(sale_id_nft1, {from: accounts[2], value: 100000});
        assert.equal(await master.getSalesCountByUser.call(accounts[1]), 0);
        assert.equal(await master.getSalesCount.call(), 0);
        assert.equal(await master.getUserBuysCount.call(accounts[2]), 1);
        //mint and sell NFT2
        await master.mintAndSell(collection_address, 'nft2',
            0, testCoinA.address, 100000, 500, {from: accounts[1]});
        assert.equal(await master.getSalesCountByUser.call(accounts[1]), 1);
        assert.equal(await master.getSalesCount.call(), 1);
        balance50 = await testCoinA.balanceOf.call(accounts[5]);
        //buy NFT 2
        sale_id_nft2 = await salePlain.getSaleId.call(collection_address, 2);
        await testCoinA.getCoin(100000, {from: accounts[2]});
        await testCoinA.approve(salePlain.address, 100000, {from: accounts[2]});
        await salePlain.bidWithToken(sale_id_nft2, 100000, {from: accounts[2]});
        balance51 = await testCoinA.balanceOf.call(accounts[5]);
        assert.equal(balance51 - balance50, 7500);
    });
    it('should sell NFt by auction', async () =>{
        //mint and sell NFT 3
        await master.mintAndSell(collection_address, 'nft3',
            1, zero_address, 100000, 5000, {from: accounts[1]});
        //bid NFT 3
        sale_id_nft3 = await saleAuction.getSaleId.call(collection_address, 3);
        sale_info = await saleAuction.getSaleInfo.call(sale_id_nft3);
        assert.equal(sale_info[0], true);
        await saleAuction.bidWithValue(sale_id_nft3, {from: accounts[2], value: 100000});
        assert.equal(await master.getSalesCountByUser.call(accounts[1]), 1);
        assert.equal(await master.getSalesCount.call(), 1);
        assert.equal(await master.getUserBidsCount.call(accounts[2]), 1);
        //mint and sell NFT 4
        await master.mintAndSell(collection_address, 'nft4',
            1, testCoinA.address, 100, 2, {from: accounts[1]});
        //bid NFT 4
        sale_id_nft4 = await saleAuction.getSaleId.call(collection_address, 4);
        await testCoinA.getCoin(100000, {from: accounts[2]});
        await testCoinA.getCoin(100000, {from: accounts[3]});
        await testCoinA.approve(saleAuction.address, 100000, {from: accounts[2]});
        await testCoinA.approve(saleAuction.address, 100000, {from: accounts[3]});
        await saleAuction.bidWithToken(sale_id_nft4, 150, {from: accounts[2]});
        assert.equal(await master.getUserBidsCount.call(accounts[2]), 2);
        await saleAuction.bidWithToken(sale_id_nft4, 200, {from: accounts[3]});
        assert.equal(await master.getUserBidsCount.call(accounts[2]), 1);
        //wait for close
        while(await saleAuction.claimable.call(sale_id_nft4, accounts[3], {from: accounts[3]})){
            await sleep(0.5);
        }
        await timeout(2000);
        //update block time
        await testCoinA.getCoin(100000, {from: accounts[2]});
        //claim NFT 4
        sale_info = await saleAuction.getSaleInfo.call(sale_id_nft4);
        //console.log(sale_info);
        assert.equal(sale_info[5], accounts[3]);
        assert.equal(await saleAuction.claimable.call(sale_id_nft4, accounts[3], {from: accounts[3]}), true);
        await saleAuction.claim(sale_id_nft4, {from: accounts[3]});
        assert.equal(await master.getUserBidsCount.call(accounts[3]), 0);
        assert.equal(await master.getUserBuysCount.call(accounts[3]), 1);
        assert.equal(await master.getSalesCount.call(), 1);
    });
});
