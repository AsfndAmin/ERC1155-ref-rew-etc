// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MyERC1155 is ERC1155, Ownable, ReentrancyGuard {

    using Strings for uint256;

    uint256 private constant TIER_1 = 1;
    uint256 private constant TIER_2 = 2;
    uint256 private constant TIER_3 = 3;
    uint256 private constant TIER_4 = 4;

    mapping(uint256 => uint256) private tokenCounts;
    mapping(uint256 => uint256) private mintPrices;
    mapping(uint256 => string) private tokenURIs;

    // Mapping to keep track of the NFT IDs of all types and their owners
    mapping(address => mapping(uint256 => uint256[])) private _nftIds;

    uint256 private raisedCap;
    uint256 private totalSaleCap;

    constructor(string memory _uri, uint256 _saleCap) ERC1155(_uri) {
        totalSaleCap = _saleCap;
    }

    function mint(uint256 tier, address account) public payable nonReentrant {
        require(tier >= 1 && tier <= 4, "Invalid tier");
        require(msg.value == mintPrices[tier], "Insufficient payment");
        require(msg.value + raisedCap <= totalSaleCap, "cannot mint more");
        uint256 tokenId;

            tokenCounts[tier]++;
            tokenId = tokenCounts[tier];
            
        uint256[] storage ids = _nftIds[account][tier];
        ids.push(tokenId);
        _mint(account, tier, 1, "");
    }

    function setMintPrice(uint256 tier, uint256 price) public onlyOwner {
        require(tier >= 1 && tier <= 4, "Invalid tier");
        mintPrices[tier] = price;
    }

    function setTotalSaleCapp(uint256 _newCap) public onlyOwner {
        require(_newCap > totalSaleCap, "Invalid cap");
        totalSaleCap = _newCap;
    }
    function currentSupply(uint256 typeId) external view returns (uint256) {
        require(typeId >= TIER_1 && typeId <= TIER_4, "Invalid type ID");
        return tokenCounts[typeId];
    }

    function getTotalEthRaised() public view returns (uint256) {
        return raisedCap;
    }

    function checkIds(address _account, uint16 _tier) public view returns(uint256[] memory){
        uint256[] memory ids = _nftIds[_account][_tier];
        return ids;
    }

    function setTokenURI(uint256 tokenId, string memory _uri) public onlyOwner {
        tokenURIs[tokenId] = _uri;
    }

    function uri(uint256 tierId) public view override returns (string memory) {
        string memory tokenURI = tokenURIs[tierId];
        return bytes(tokenURI).length > 0 ? tokenURI : super.uri(tierId);
    }

    function tokenUri(uint256 tierId, uint256 tokenId)public view returns (string memory) {
        string memory tokenURI = tokenURIs[tierId];
        return bytes(tokenURI).length > 0 ? string(abi.encodePacked(tokenURI, tokenId.toString())) : super.uri(tierId);
    }
}
