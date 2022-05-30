// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

//import '@openZeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

import "./libraries/Ownable.sol";
import "./interface/IERC2981.sol";


contract NFTCollection is Ownable, ERC721Enumerable, ERC721URIStorage {

    // Keep a mapping of token ids and corresponding IPFS hashes
    mapping(string => uint8) hashes;
    // Maximum amounts of mintable tokens
    uint256 public MAX_SUPPLY;
    // Address of the royalties recipient
    address public royaltiesReceiver;
    // Percentage of each sale to pay as royalties 2.5 = 250 in bips
    uint256 public  royaltiesPercentageInBips ;
    //Overrides ERC-721's _baseURI function
    string private baseURI;
    //metaInfo
    string public metaInfo;
    // Events
    event Mint(uint256 tokenId, address recipient);

    constructor(string memory name_, string memory symbol_, string memory baseURI_, uint max_supply_)
    ERC721(name_, symbol_) {
        baseURI = baseURI_;
        MAX_SUPPLY = max_supply_;
        require(uint(uint96(MAX_SUPPLY)) == MAX_SUPPLY, "Too many supplies: overflow");
    }

    /** Overrides ERC-721's _baseURI function */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setMetaInfo(string memory metaInfo_) external onlyOwner {
        metaInfo = metaInfo_;
    }

    function setRoyaltiesPercentageInBips(uint newRoyaltiesPercentageInBips)
    external onlyOwner {
        royaltiesPercentageInBips = newRoyaltiesPercentageInBips;
    }

    function setRoyaltiesReceiver(address newRoyaltiesReceiver)
    external onlyOwner {
        royaltiesReceiver = newRoyaltiesReceiver;
    }


    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _salePrice - sale price of the NFT asset specified by _tokenId
    /// @return receiver - address of who should be sent the royalty payment
    /// @return royaltyAmount - the royalty payment amount for _value sale price
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view
    returns (address receiver, uint256 royaltyAmount) {
        _tokenId;
        uint256 royalties = (_salePrice * royaltiesPercentageInBips) / 10000 ;
        return (royaltiesReceiver, royalties);
    }


    /// @notice Mints tokens
    /// @param recipient - the address to which the token will be transfered
    /// @param hash - the IPFS hash of the token's resource
    /// @return tokenId - the id of the token
    function mint(address recipient, string memory hash)
    external onlyOwner
    returns (uint256 tokenId)
    {
        require(totalSupply() <= MAX_SUPPLY, "All tokens minted");
        require(bytes(hash).length > 0); // dev: Hash can not be empty!
        require(hashes[hash] != 1); // dev: Can't use the same hash twice
        hashes[hash] = 1;
        uint256 newItemId = totalSupply() + 1;
        _safeMint(recipient, newItemId);
        _setTokenURI(newItemId, hash);
        emit Mint(newItemId, recipient);
        return newItemId;
    }

    //overrides for compiler check
    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    //overrides for compiler check
    function _burn(uint256 tokenId)
    internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    //overrides for compiler check
    function tokenURI(uint256 tokenId)
    public view override(ERC721, ERC721URIStorage)
    returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /// @notice Informs callers that this contract supports ERC2981
    function supportsInterface(bytes4 interfaceId)
    public view override(ERC721, ERC721Enumerable)
    returns (bool) {
        return interfaceId == 0x2a55205a || //ERC2981
        super.supportsInterface(interfaceId);
    }

    //note that logical owner of collection should be master contract
    //yet actual owner is recoreded in master contract
    function transferByMaster(address from, address to, uint tokenId) external onlyOwner {
        _transfer(from, to, tokenId);
    }
}
