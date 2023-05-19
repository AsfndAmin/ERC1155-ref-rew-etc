// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Staking is ERC1155Holder, Ownable, Pausable, ReentrancyGuard {

    using SafeERC20 for IERC20;
    IERC20 rewardToken;
    IERC1155 nft;



    uint256 public lockingTimesAvailable;
    uint256 public totalSharesCreated;

    struct NFTLock {
        address owner;
        uint256 nftId;
        uint256 baseShares;
        uint256 bonusShares;
        uint256 timeLockShare;
        uint256 timeLock;
        uint256 unlockTime;
        bool staked;
    }

    
    // Mapping of staker addresses to their total shares
    mapping(address => uint256) public totalShares;

    //mapping of nfts per tier staked
    mapping(uint256 => uint256) public countPerTier;

    // Mapping of staker addresses to their total shares
    mapping(address => uint256) public addressIndex;

    address[] public stakers;

    // Mapping of staked NFT lock IDs to their lock details
    mapping(uint256 => NFTLock) public NFTId;

    // Mapping of staker addresses to their nft Ids
    mapping(address => uint256[]) public stakersNfts;

    //mapping(address => uint256) public AvailableRewards;

    mapping(uint256 => uint256) public lockTimes;  // [2629743 ,7889229, 15778458, 34186659]
    mapping(uint256 => uint256) public baseShare;  // [50 ,300, 1500, 4000]
    mapping(uint256 => uint256) public bonusSharePercentage; // [0 ,100, 200, 250]  100 for 10%
    mapping(uint256 => uint256) public timeLockBonusPercentage; // [0 ,100, 150, 250]  100 for 10%

    constructor(){ 
        
    }

    function stake(uint256[] calldata tokenIds, uint256[] calldata lockTime) external whenNotPaused nonReentrant{
        require(tokenIds.length == lockTime.length, "length mis matched");
        for(uint256 i = 0; i < tokenIds.length; i++){
            require(lockTime[i] <= lockingTimesAvailable && lockTime[i] != 0, "lock timr error");
            require(nft.balanceOf(msg.sender, tokenIds[i]) == 1 , "caller not owner");
            uint256 tier = getTier(tokenIds[i]);
            uint256 _baseShare = baseShare[tier];
            uint256 _bonusShare = (_baseShare * bonusSharePercentage[tier])/1000;
            uint256 _timeLockShare = (_baseShare * timeLockBonusPercentage[lockTime[i]])/1000;
            uint256 _totalShare = _baseShare + _bonusShare + _timeLockShare;
            uint256 _lockTime = lockTimes[lockTime[i]];
            nft.safeTransferFrom(msg.sender, address(this), tokenIds[i], 1, "");
            NFTId[tokenIds[i]] = NFTLock(
                msg.sender,
              tokenIds[i],
              _baseShare,
               _bonusShare,
                _timeLockShare,
                 _lockTime,
                  block.timestamp + _lockTime,
                   true);

            totalSharesCreated += _totalShare;
            totalShares[msg.sender] += _totalShare;
            stakersNfts[msg.sender].push(tokenIds[i]);
            stakers.push(msg.sender);
            addressIndex[msg.sender] = stakers.length - 1;
            countPerTier[tier] += 1;

        }

    }


    function unstake(uint256[] calldata tokenIds) external whenNotPaused nonReentrant{
             for(uint256 i = 0; i < tokenIds.length; i++){
                 require( NFTId[tokenIds[i]].owner == msg.sender, "caller not owner");
                 require(NFTId[tokenIds[i]].unlockTime < block.timestamp, "not unlocked");
                 nft.safeTransferFrom(address(this), msg.sender, tokenIds[i], 1, "");
                 uint256 shares = NFTId[tokenIds[i]].baseShares + NFTId[tokenIds[i]].bonusShares + NFTId[tokenIds[i]].timeLockShare;
                 totalShares[msg.sender] -= shares;
                 totalSharesCreated -= shares;
                 if(totalShares[msg.sender] == 0){
                     uint256 currentIndex = addressIndex[msg.sender];
                     stakers[currentIndex] = stakers[stakers.length - 1];
                     addressIndex[stakers[currentIndex]] = currentIndex;
                     stakers.pop(); 
                 }

                 for(uint256 j = 0; j < stakersNfts[msg.sender].length; j++){
                        if (stakersNfts[msg.sender][j] == tokenIds[i]) {
                        // Swap the last element with the element to remove, then pop it off
                        stakersNfts[msg.sender][j] = stakersNfts[msg.sender][stakersNfts[msg.sender].length - 1];
                         stakersNfts[msg.sender].pop();
                        break;
                         }
                 }
                 
                 delete NFTId[tokenIds[i]];
                 uint256 tier = getTier(tokenIds[i]);
                 countPerTier[tier] -= 1;
             }
    }

    function extendLock(uint256 nftId, uint256 _newTime) external whenNotPaused nonReentrant{
            require( NFTId[nftId].owner == msg.sender && NFTId[nftId].staked == true, "caller not owner");
            require( NFTId[nftId].timeLock < _newTime && _newTime <= lockingTimesAvailable, "caller not owner"); 
                uint256 tier = getTier(nftId);
            uint256 _baseShare = baseShare[tier];
            uint256 _bonusShare = (_baseShare * bonusSharePercentage[tier])/1000;
            uint256 _timeLockShare = (_baseShare * timeLockBonusPercentage[_newTime])/1000;
            uint256 totalShare = _baseShare + _bonusShare + _timeLockShare;
            uint256 _lockTime = lockTimes[_newTime];
            uint256 oldShare = NFTId[nftId].baseShares + NFTId[nftId].bonusShares +NFTId[nftId].timeLockShare;
            uint256 addedShare = totalShare - oldShare;
            NFTId[nftId] = NFTLock(
            msg.sender,
              nftId,
              _baseShare,
               _bonusShare,
                _timeLockShare,
                 _lockTime,
                  block.timestamp + _lockTime,
                   true);

            totalSharesCreated += addedShare;
            totalShares[msg.sender] += addedShare;
    }


    function setLockTimes(uint256[] calldata _locktimes, uint256[] calldata _timestamps) external onlyOwner{
        require(_locktimes.length == _timestamps.length, "length mismatched");
        require(lockingTimesAvailable!=0 && _locktimes.length == lockingTimesAvailable - 1, "lock time error");
        for(uint256 i = 0; i < _locktimes.length; i++){
            lockTimes[_locktimes[i]] = _timestamps[i];
        } 
    }

    function setBonusSharePercentage(uint256[] calldata _index, uint256[] calldata _bonusSharePercentage) external onlyOwner{
        require(_index.length == _bonusSharePercentage.length, "length mismatched");
        for(uint256 i = 0; i < _index.length; i++){
            bonusSharePercentage[_index[i]] = _bonusSharePercentage[i];
        }
    }

    function setBaseShares(uint256[] calldata _index, uint256[] calldata _baseShares) external onlyOwner{
        require(_index.length == _baseShares.length, "length mismatched");
        for(uint256 i = 0; i < _index.length; i++){
            baseShare[_index[i]] = _baseShares[i];
        }
    }

    function setTimeLockBonusPercentage(uint256[] calldata _index, uint256[] calldata _timeLockBonus) external onlyOwner{
        require(_index.length == _timeLockBonus.length, "length mismatched");
        for(uint256 i = 0; i < _index.length; i++){
            timeLockBonusPercentage[_index[i]] = _timeLockBonus[i];
        }
    }

    function setTotalLockingTimes(uint256 _value) external onlyOwner{
        require(_value != 0, "cannot be 0");
        lockingTimesAvailable = _value;
    }

    // function distributeReward(uint256 startIndex, uint256 endIndex, uint256 totalReward) external onlyOwner{

    //     require(startIndex < endIndex && endIndex < stakers.length, "index error");
    //     uint256 rewardPerShare = totalReward/totalSharesCreated;
    //     require(rewardPerShare > 0, "reward amount less than shares");
    //     for(uint256 i = startIndex; i <= endIndex; i++){
    //         uint256 rewardAmount = (totalShares[stakers[i]])*rewardPerShare;
    //         AvailableRewards[stakers[i]] += rewardAmount;

    //     }
    // }

    function unlockNfts(uint256[] calldata ids) external onlyOwner{
            for(uint256 i = 0; i < ids.length; i++){
                NFTId[ids[i]].unlockTime = 0;
            }
    }
    
    function depositRewardTokens(uint256 amount) external onlyOwner{
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    // function claimReward() external whenNotPaused nonReentrant{
    //     uint256 availableAmount = AvailableRewards[msg.sender];
    //     require (availableAmount > 0, "not enough rewards");
    //     rewardToken.safeTransferFrom(msg.sender, address(this), availableAmount);
    //     AvailableRewards[msg.sender] = 0;
    // }

    function totalStakers() external view returns(uint256){
            return stakers.length - 1;
    }



    function getTier(uint256 tokenId) public pure returns (uint8) {
    uint8 tier;
    while (tokenId != 0) {
        tier = uint8(tokenId % 10);
        tokenId /= 10;
    }
        return tier;
}


    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }


}

