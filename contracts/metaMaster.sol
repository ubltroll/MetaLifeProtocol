// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import './NFTInfoStorage.sol';
import './NFTCollection.sol';
import './interface/ISales.sol';

contract metaMaster is Ownable, NFTInfoStorage{
    //------------
    //collection manager
    //------------
    event NewCollection(address indexed creator, address collection);

    mapping(address => address) public collectionOwner;
    mapping (address => address[]) public userOwnedCollections;

    function userOwnedCollectionNum(address user) public view returns(uint){
        return userOwnedCollections[user].length;
    }

    function createCollection(string memory _name, string memory _symbol,
            string memory _baseURI, uint _max_supply, string memory _metaInfo,
            address royaltiesReceiver, uint royaltiesPercentageInBips) public returns(address) {
        require(royaltiesPercentageInBips + feeInBips <= 10000, "Royalty overflow");
        NFTCollection _collection = new NFTCollection(_name, _symbol, _baseURI, _max_supply);
        _collection.setMetaInfo(_metaInfo);
        _collection.setRoyaltiesPercentageInBips(royaltiesPercentageInBips);
        _collection.setRoyaltiesReceiver(royaltiesReceiver);
        collectionOwner[address(_collection)] = msg.sender;
        userOwnedCollections[msg.sender].push(address(_collection));
        emit NewCollection(msg.sender, address(_collection));
        return address(_collection);
    }

    function setCollectionMetaInfo(address _collection, string memory _metaInfo) external{
        require(collectionOwner[address(_collection)] == msg.sender, "Not owner");
        NFTCollection(_collection).setMetaInfo(_metaInfo);
    }

    function setCollectionRoyalty(address _collection, address royaltiesReceiver, uint royaltiesPercentageInBips) external{
        require(collectionOwner[address(_collection)] == msg.sender, "Not owner");
        require(royaltiesPercentageInBips + feeInBips <= 10000, "Royalty overflow");
        NFTCollection(_collection).setRoyaltiesReceiver(royaltiesReceiver);
        NFTCollection(_collection).setRoyaltiesPercentageInBips(royaltiesPercentageInBips);
    }

    //------------
    //sales: manager
    //------------

    address[] public marketSales;

    function addMarketSale(address _sale) external onlyOwner{
        marketSales.push(_sale);
        setSale(_sale, true);
    }

    //------------
    //sales: interaction
    //------------

    function sell(address collection, uint token_id,
        uint market, address _token, uint _price, uint _due) public {
        require(market < marketSales.length, "Wrong market");
        require(IERC721(collection).ownerOf(token_id) == msg.sender, "Not owner");
        require(tokenIsSupported[_token], "Wrong token");
        require(_price == uint256(uint128(_price)), "Price overflow");
        NFTCollection(collection).transferByMaster(msg.sender, marketSales[market], token_id);
        ISales(marketSales[market]).create(collection, token_id, msg.sender, _token, _price, _due);
    }

    //------------
    //fee manager
    //------------

    address public feeCollector;

    uint public feeInBips;

    function setFeeConfig(address _feeCollector, uint _feeInBips) external onlyOwner{
        feeCollector = _feeCollector;
        feeInBips = _feeInBips;
    }

    mapping(address => bool) public tokenIsSupported;

    function setTokenSupport(address _token, bool _status) external onlyOwner{
        tokenIsSupported[_token] = _status;
    }

    //------------
    //nft manager
    //------------

    function mint(address _collection, address _recipient, string memory _hash) public returns(uint){
        require(collectionOwner[address(_collection)] == msg.sender, "Not owner");
        return NFTCollection(_collection).mint(_recipient, _hash);
    }

    function mintAndSell(address _collection, string memory _hash,
        uint market, address _token, uint _price, uint _due) external {
        uint _tokenId = mint(_collection, msg.sender, _hash);
        sell(_collection, _tokenId, market, _token, _price, _due);
    }

    //------------
    //constructor
    //------------

    constructor() {
        feeCollector = msg.sender;
        feeInBips = 250;
        tokenIsSupported[address(0)] = true;
    }
}
