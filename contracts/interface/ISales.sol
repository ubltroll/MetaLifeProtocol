// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22;

interface ISales{
    //events
    event CreateSale(address indexed _contract, uint _tokenId, address seller, address token, uint _price, uint _due);
    event UpdateSale(address indexed _contract, uint _tokenId, address seller, address token, uint _price, uint _due);
    event CancelSale(address indexed _contract, uint _tokenId);
    event ConfirmSale(address indexed _contract, uint _tokenId, address indexed solder, address indexed buyer, address token, uint _price);
    event NewBid(address indexed _contract, uint _tokenId, address indexed bidder, address token, uint _price);
    //Owner Interaction
    function create(address _contract, uint _tokenId, address seller, address _token, uint _price, uint _due) external returns (uint _saleId);
    function cancel(uint _saleId) external;
    function updatePrice(uint _saleId, address _token, uint _price) external;
    function updateDuration(uint _saleId, uint _due) external;
    //Customer Interaction
    function bidWithValue(uint _saleId) external payable;
    function bidWithToken(uint _saleId, uint _amount) external;
    function claim(uint _saleId) external;
    function claimable(uint _saleId) external view returns (bool);
    //Views
    function getSaleId(address _contract, uint _tokenId) external view returns (uint _saleId);
    function getSaleInfo(uint _saleId) external view returns (bool _isOpen, address _token, uint _price, uint _due, address seller, address _bidder);
    function getSaleInfo(address _contract, uint _tokenId) external view returns (bool _isOpen, address _token, uint _price, uint _due, address seller, address _bidder);
}
