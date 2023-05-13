// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is ERC1155Holder, Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;

    struct NFTLock {
        address owner;
        uint256 nftId;
        uint256 baseShares;
        uint256 bonusShares;
        uint256 timeLock;
        uint256 unlockDate;
    }

    
    // Mapping of staked NFT lock IDs to their lock details
    mapping(uint256 => NFTLock) private NFTId;

    // Mapping of staker addresses to their nft Ids
    mapping(address => uint256[]) private stakersNfts;

    mapping(uint256 => uint256) public lockTimes;
    mapping(uint256 => uint256) public baseShare;
    mapping(uint256 => uint256) public bonusShare;
    mapping(uint256 => uint256) public timeLockBonusShare;

    constructor(){ 
        
    }

    function stake(uint256[] calldata tokenIds, uint256[] calldata lockTime) external {
        require(tokenIds.length == lockTime.length, "length mis matched");
        
        


    }

    function getTier(uint256 number) public pure returns (uint8) {
    uint8 tier;
    while (number != 0) {
        tier = uint8(number % 10);
        number /= 10;
    }
        return tier;
}

}

