// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyERC1155 is ERC1155, Ownable {
    uint256 private constant TIER_1 = 1;
    uint256 private constant TIER_2 = 2;
    uint256 private constant TIER_3 = 3;
    uint256 private constant TIER_4 = 4;

    mapping(uint256 => uint256) private tokenCounts;
    mapping(uint256 => uint256) private mintPrices;
    mapping(uint256 => string) private tokenURIs;
    uint256 private raisedCap;
    uint256 private totalSaleCap;

    constructor(string memory _uri) ERC1155(_uri) {}

    function mint(uint256 tier, address account) public payable {
        require(tier >= 1 && tier <= 4, "Invalid tier");
        require(msg.value == mintPrices[tier], "Insufficient payment");
        require(msg.value + raisedCap <= totalSaleCap, "cannot mint more");
        uint256 tokenId;
        if (tier == 1) {
            tokenCounts[TIER_1]++;
            tokenId = tokenCounts[TIER_1];
            
        } else if (tier == 2) {
            tokenCounts[TIER_2]++;
            tokenId = tokenCounts[TIER_2];
            
        } else if (tier == 3) {
            tokenCounts[TIER_3]++;
            tokenId = tokenCounts[TIER_3];
            
        } else {
            tokenCounts[TIER_4]++;
            tokenId = tokenCounts[TIER_4];
            
        }
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

    function getTotalEthUsed() public view returns (uint256) {
        return raisedCap;
    }

    function setTokenURI(uint256 tokenId, string memory _uri) public onlyOwner {
        tokenURIs[tokenId] = _uri;
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return tokenURIs[tokenId];
    }
}
