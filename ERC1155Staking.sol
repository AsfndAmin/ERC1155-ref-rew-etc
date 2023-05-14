// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is ERC1155Holder, Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;
    IERC20 rewardToken;
    IERC1155 nft;



    uint256 lockingTimesAvailable;

    struct NFTLock {
        address owner;
        uint256 nftId;
        uint256 baseShares;
        uint256 bonusShares;
        uint256 timeLockShare;
        uint256 timeLock;
        uint256 unlockDate;
    }

    
    // Mapping of staked NFT lock IDs to their lock details
    mapping(uint256 => NFTLock) private NFTId;

    // Mapping of staker addresses to their nft Ids
    mapping(address => uint256[]) private stakersNfts;

    mapping(uint256 => uint256) public lockTimes;
    mapping(uint256 => uint256) public baseShare;
    mapping(uint256 => uint256) public bonusSharePercentage;
    mapping(uint256 => uint256) public timeLockBonusPercentage;

    constructor(){ 
        
    }

    function stake(uint256[] calldata tokenIds, uint256[] calldata lockTime) external{
        require(tokenIds.length == lockTime.length, "length mis matched");
        for(uint256 i = 0; i < tokenIds.length; i++){
            require(lockTime[i] <= lockingTimesAvailable && lockTime[i] != 0, "lock timr error");
            require(nft.balanceOf(msg.sender, tokenIds[i]) == 1 , "caller not owner");
            uint256 tier = getTier(tokenIds[i]);
            uint256 _baseShare = baseShare[tier];
            uint256 _bonusShare = (_baseShare * bonusSharePercentage[tier])/1000;
            uint256 _timeLockShare = (_baseShare * timeLockBonusPercentage[lockTime[i]])/1000;
            uint256 _lockTime = lockTimes[lockTime[i]];
            nft.safeTransferFrom(msg.sender, address(this), tokenIds[i], 1, "");
             NFTId[tokenIds[i]] = NFTLock(msg.sender, tokenIds[i], _baseShare, _bonusShare, _timeLockShare, _lockTime, block.timestamp +_lockTime );
        }

    }

    function getTier(uint256 tokenId) public pure returns (uint8) {
    uint8 tier;
    while (tokenId != 0) {
        tier = uint8(tokenId % 10);
        tokenId /= 10;
    }
        return tier;
}


}

