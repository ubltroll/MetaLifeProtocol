// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
import './interface/ISales.sol';
import './libraries/StructuredLinkedList.sol';
import './RecordPacker.sol';

contract NFTInfoStorage is RecordPacker {
    using StructuredLinkedList for StructuredLinkedList.List;
    //------------
    //storage: market_sale
    //------------
    //(collection, token_id)
    StructuredLinkedList.List nftsInSale;
    //(collection, token_id) -> sales address
    mapping (uint256 => address) saleBook;
    //user address -> (collection, token_id)
    mapping (address => StructuredLinkedList.List) userBids;
    //user address -> (collection, token_id)
    mapping (address => salesInfo[]) userBuys;
    //user address -> (collection, token_id)
    mapping (address => StructuredLinkedList.List) userSales;

    struct salesInfo {
       address sales;
       address collection;
       uint96 token_id;
       address token;
       uint128 price;
       uint64 duetime;
       address seller;
    }

    mapping (address => bool) isSale;

    function setSale(address _sale, bool _status) internal{
        isSale[_sale] = _status;
    }

    //------------
    //update records
    //------------

    function recordNewItem(uint256 record, address seller) external {
        require(isSale[msg.sender]);
        nftsInSale.pushFront(record);
        saleBook[record] = msg.sender;
        userSales[seller].pushFront(record);
    }

    function recordItemSold(uint256 record, address seller, address buyer, address token, uint256 price) external {
        require(isSale[msg.sender]);
        (address collcetion, uint96 token_id) = resovleRecord(record);
        delete saleBook[record];
        userSales[seller].remove(record);
        nftsInSale.remove(record);
        userBuys[buyer].push(salesInfo(msg.sender, collcetion, token_id,
            token, uint128(price), uint64(block.timestamp), seller));
    }

    function recordItemCancel(uint256 record, address seller) external {
        require(isSale[msg.sender]);
        delete saleBook[record];
        userSales[seller].remove(record);
        nftsInSale.remove(record);
    }

    function recordNewBid(uint256 record, address bidder) external {
        require(isSale[msg.sender]);
        userBids[bidder].pushFront(record);
    }

    function recordDelBid(uint256 record, address bidder) external {
        require(isSale[msg.sender]);
        userBids[bidder].remove(record);
    }

    //------------
    //get records
    //------------

    function getSaleInfo(address collection, uint96 token_id) public view returns (salesInfo memory){
        uint256 record = packRecord(collection, token_id);
        return getSaleInfoByRecord(record);
    }

    function getSaleInfoByRecord(uint256 record) internal view returns (salesInfo memory){
        address sales = saleBook[record];
        if (sales == address(0)){
            return salesInfo(address(0), address(0), 0, address(0), 0, 0, address(0));
        }
        (bool _isOpen, address _token, uint _price, uint _due, address _seller,) =
            ISales(sales).getSaleInfo(record);
        if (!_isOpen) {
            sales = address(0);
        }
        (address _contract, uint _tokenId) = resovleRecord(record);
        return salesInfo(sales, _contract, uint96(_tokenId), _token, uint128(_price), uint64(_due), _seller);
    }

    function getSales(uint256 limit, uint256 offset) external view returns(salesInfo[] memory records){
        records = new salesInfo[](limit);
        uint256 cursor;
        bool toContinue = true;
        for(uint i; (i < offset) && toContinue && (cursor > 0 || i == 0); i++){
            (toContinue, cursor) = nftsInSale.getNextNode(cursor);
        }
        for(uint i; (i < limit) && toContinue && (cursor > 0 || i == 0); i++){
            (toContinue, cursor) = nftsInSale.getNextNode(cursor);
            if(toContinue) records[i] = getSaleInfoByRecord(cursor);
        }
    }

    function getSalesCount() external view returns(uint){
        return nftsInSale.sizeOf();
    }

    function getSalesByCollection(address collcetion, uint256 limit, uint256 offset) external view returns(salesInfo[] memory records){
        records = new salesInfo[](limit);
        for(uint i; i < limit; i++){
            records[i] = getSaleInfo(collcetion, uint96(offset + limit));
        }
    }

    function getSalesByUser(address user, uint256 limit, uint256 offset) external view returns(salesInfo[] memory records){
        records = new salesInfo[](limit);
        uint256 cursor;
        bool toContinue = true;
        for(uint i; (i < offset) && toContinue && (cursor > 0 || i == 0); i++){
            (toContinue, cursor) = userSales[user].getNextNode(cursor);
        }
        for(uint i; (i < limit) && toContinue && (cursor > 0 || i == 0); i++){
            (toContinue, cursor) = userSales[user].getNextNode(cursor);
            if(toContinue) records[i] = getSaleInfoByRecord(cursor);
        }
    }

    function getSalesCountByUser(address user) external view returns(uint){
        return userSales[user].sizeOf();
    }

    function getUserBids(address user, uint256 limit, uint256 offset) external view returns(salesInfo[] memory records){
        records = new salesInfo[](limit);
        uint256 cursor;
        bool toContinue = true;
        for(uint i; (i < offset) && toContinue && (cursor > 0 || i == 0); i++){
            (toContinue, cursor) = userBids[user].getNextNode(cursor);
        }
        for(uint i; (i < limit) && toContinue && (cursor > 0 || i == 0); i++){
            (toContinue, cursor) = userBids[user].getNextNode(cursor);
            if(toContinue) records[i] = getSaleInfoByRecord(cursor);
        }
    }

    function getUserBidsCount(address user) external view returns(uint){
        return userBids[user].sizeOf();
    }

    function getUserBuys(address user, uint256 limit, uint256 offset) external view returns(salesInfo[] memory records){
        records = new salesInfo[](limit);
        uint length = userBuys[user].length;
        if (offset > length){
            offset = length;
        }
        if (offset + limit > length){
            limit = length - offset;
        }
        for(uint i; i<limit; i++){
            records[i] = userBuys[user][length - i];
        }
    }

    function getUserBuysCount(address user) external view returns(uint){
        return userBuys[user].length;
    }
}
