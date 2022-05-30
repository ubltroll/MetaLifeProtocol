// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './metaMaster.sol';
import './NFTInfoStorage.sol';
import './RecordPacker.sol';
import './NFTCollection.sol';

contract saleAuction is ISales, RecordPacker{
    struct saleAuctionItem {
       address seller;
       address token;
       uint128 price;
       uint64 duetime;
       address bidder;
    }

    mapping (uint256 => saleAuctionItem) saleItems;

    address public masterAddress;

    constructor(address master){
        masterAddress = master;
    }

    //Owner Interaction
    function create(address _contract, uint _tokenId, address seller,
        address _token, uint _price, uint _due) external override returns (uint record){
            //check
            require(IERC721(_contract).ownerOf(_tokenId) == address(this));
            require(_due > block.timestamp, 'Time underflow');
            require(_price == uint256(uint128(_price)), 'Price overflow');
            //update
            record = packRecord(_contract, uint96(_tokenId));
            saleItems[record] = saleAuctionItem(seller, _token, uint128(_price), uint64(_due), address(0));
            //record
            NFTInfoStorage(masterAddress).recordNewItem(record, seller);
            emit CreateSale(_contract, _tokenId, seller, _token, _price, _due);
        }

    function cancel(uint _saleId) external override{
        (address _contract, uint _tokenId) = resovleRecord(_saleId);
        //check
        require(saleItems[_saleId].seller == msg.sender , 'Not owner or item sold');
        require(saleItems[_saleId].bidder == address(0) , 'Has bid!');
        //update
        delete saleItems[_saleId];
        IERC721(_contract).transferFrom(address(this), msg.sender, _tokenId);
        //record
        NFTInfoStorage(masterAddress).recordItemCancel(_saleId, msg.sender);
        emit CancelSale(_contract, _tokenId);
    }

    function updatePrice(uint _saleId, address _token, uint _price) external override{
        (address _contract, uint _tokenId) = resovleRecord(_saleId);
        //check
        require(saleItems[_saleId].seller == msg.sender , 'Not owner or item sold');
        require(metaMaster(masterAddress).tokenIsSupported(_token), 'Wrong Token');
        require(saleItems[_saleId].bidder == address(0) , 'Has bid!');
        //update
        saleItems[_saleId].token = _token;
        saleItems[_saleId].price = uint128(_price);
        //record
        emit UpdateSale(_contract, _tokenId, msg.sender,
            saleItems[_saleId].token, saleItems[_saleId].price, saleItems[_saleId].duetime);
    }

    function updateDuration(uint _saleId, uint _due) external override{
        (address _contract, uint _tokenId) = resovleRecord(_saleId);
        //check
        require(saleItems[_saleId].seller == msg.sender , 'Not owner or item sold');
        require(_due > block.timestamp, 'Time underflow');
        require(saleItems[_saleId].bidder == address(0) , 'Has bid!');
        //update
        saleItems[_saleId].duetime = uint64(_due);
        //record
        emit UpdateSale(_contract, _tokenId, msg.sender,
            saleItems[_saleId].token, saleItems[_saleId].price, saleItems[_saleId].duetime);
    }

    //Customer Interaction
    function bidWithValue(uint _saleId) external override payable{
        (address _contract, uint _tokenId) = resovleRecord(_saleId);
        //check
        require(saleItems[_saleId].duetime > block.timestamp, 'Invalid sale');
        require(saleItems[_saleId].token == address(0), 'Wrong payment');
        if (saleItems[_saleId].bidder != address(0)){
            require(msg.value > saleItems[_saleId].price, 'Insufficient payment');
        } else {
            require(msg.value >= saleItems[_saleId].price, 'Insufficient payment');
        }
        //handle payment
        msg.value;
        //remove previous bid
        if (saleItems[_saleId].bidder != address(0)){
            payable(saleItems[_saleId].bidder).transfer(saleItems[_saleId].price);
            NFTInfoStorage(masterAddress).recordDelBid(_saleId, saleItems[_saleId].bidder);
        }
        //place bid
        saleItems[_saleId].bidder = msg.sender;
        saleItems[_saleId].price = uint128(msg.value);
        //record
        NFTInfoStorage(masterAddress).recordNewBid(_saleId, msg.sender);
        emit NewBid(_contract, _tokenId, msg.sender, saleItems[_saleId].token, msg.value);
    }

    function bidWithToken(uint _saleId, uint _amount) external override{
        (address _contract, uint _tokenId) = resovleRecord(_saleId);
        //check
        require(saleItems[_saleId].duetime > block.timestamp, 'Invalid sale');
        require(saleItems[_saleId].token != address(0), 'Wrong payment');
        if (saleItems[_saleId].bidder != address(0)){
            require(_amount > saleItems[_saleId].price, 'Insufficient payment');
        } else {
            require(_amount >= saleItems[_saleId].price, 'Insufficient payment');
        }
        //handle payment
        IERC20(saleItems[_saleId].token).transferFrom(msg.sender, address(this), _amount);
        //remove previous bid
        if (saleItems[_saleId].bidder != address(0)){
            IERC20(saleItems[_saleId].token).transfer(saleItems[_saleId].bidder, saleItems[_saleId].price);
            NFTInfoStorage(masterAddress).recordDelBid(_saleId, saleItems[_saleId].bidder);
        }
        //place bid
        saleItems[_saleId].bidder = msg.sender;
        saleItems[_saleId].price = uint128(_amount);
        //record
        NFTInfoStorage(masterAddress).recordNewBid(_saleId, msg.sender);
        emit NewBid(_contract, _tokenId, msg.sender, saleItems[_saleId].token, _amount);
    }

    function claim(uint _saleId) external override{
        //check
        (address _contract, uint _tokenId) = resovleRecord(_saleId);
        require(claimable(_saleId), 'Cannot claim');
        //handle payment
        uint _amount = saleItems[_saleId].price;
        (address royaltiesReceiver, uint royalties) = NFTCollection(_contract).royaltyInfo(_tokenId, _amount);
        uint fee = metaMaster(masterAddress).feeInBips() * _amount / 10000;
        if (saleItems[_saleId].token == address(0)){
            payable(metaMaster(masterAddress).feeCollector()).transfer(fee);
            payable(royaltiesReceiver).transfer(royalties);
            payable(saleItems[_saleId].seller).transfer(_amount - fee - royalties);
        } else {
            IERC20(saleItems[_saleId].token).transfer(metaMaster(masterAddress).feeCollector(), fee);
            IERC20(saleItems[_saleId].token).transfer(royaltiesReceiver, royalties);
            IERC20(saleItems[_saleId].token).transfer(saleItems[_saleId].seller, _amount-fee-royalties);
        }
        //delivery item
        IERC721(_contract).transferFrom(address(this), msg.sender, _tokenId);
        //record
        NFTInfoStorage(masterAddress).recordDelBid(_saleId, msg.sender);
        NFTInfoStorage(masterAddress).recordItemSold(_saleId, saleItems[_saleId].seller, msg.sender,
            saleItems[_saleId].token, _amount);
        emit ConfirmSale(_contract, _tokenId, saleItems[_saleId].seller, msg.sender,
            saleItems[_saleId].token, _amount);
        //update
        delete saleItems[_saleId];
    }

    function claimable(uint _saleId) public override view returns (bool){
        return saleItems[_saleId].duetime <= block.timestamp && saleItems[_saleId].bidder == msg.sender;
    }

    //Views
    function getSaleId(address _contract, uint _tokenId) public override pure returns (uint _saleId){
        return packRecord(_contract, uint96(_tokenId));
    }

    function getSaleInfo(uint _saleId) public override view returns (bool _isOpen, address _token,
         uint _price, uint _due, address _seller, address _bidder){
        _token = saleItems[_saleId].token;
        _price = saleItems[_saleId].price;
        _due = saleItems[_saleId].duetime;
        _seller = saleItems[_saleId].seller;
        _isOpen = _due > block.timestamp;
        _bidder = saleItems[_saleId].bidder;
    }

    function getSaleInfo(address _contract, uint _tokenId) public override view
    returns (bool, address, uint, uint, address, address){
        return getSaleInfo(getSaleId(_contract, _tokenId));
    }
}
