// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Staking is ERC1155Holder, Ownable, Pausable, ReentrancyGuard {

    IERC1155 nft;
    uint256 public lockingTimesAvailable;
    uint256 public totalSharesCreated;

    struct NFTLock {
        address owner;
        uint256 nftId;
        uint256 baseShares;
        uint256 bonusShares;
        uint256 timeLockShare;
        uint256 lockTime;
        uint256 unlockTime;
        bool staked;
    }

    
    // Mapping of staker addresses to their total shares
    mapping(address => uint256) public totalShares;

    //mapping of nfts per tier staked
    mapping(uint256 => uint256) public countPerTier;

    // Mapping of staker addresses to their index in array
    mapping(address => uint256)  addressIndex;

    address[] public stakers;

    // Mapping of staked NFT lock IDs to their lock details
    mapping(uint256 => NFTLock) public NFTId;

    // Mapping of staker addresses to their nft Ids
    mapping(address => uint256[]) stakersNfts;

    //mapping(address => uint256) public AvailableRewards;
                                                    //[1,2,3,4]
    mapping(uint256 => uint256) public lockTimes;  // [60 ,7889229, 15778458, 34186659]
    mapping(uint256 => uint256) public baseShare;  // [50 ,300, 1500, 4000]
    mapping(uint256 => uint256) public bonusSharePercentage; // [0 ,100, 200, 250]  100 for 10%
    mapping(uint256 => uint256) public timeLockBonusPercentage; // [0 ,100, 150, 250]  100 for 10%

    event staked(address owner, uint256 nftId, uint256 shares, uint256 unlocktime);
    event lockExtended(uint256 nftId, uint256 newUnlockTime);
    event withdrawn(uint256[]  unstaked);  

 
    constructor(){ 
        
    }

    function stake(uint256[] calldata tokenIds, uint256[] calldata lockTime) external whenNotPaused nonReentrant{
        require(tokenIds.length == lockTime.length, "length mis matched");
        for(uint256 i = 0; i < tokenIds.length; i++){
            require(lockTime[i] <= lockingTimesAvailable && lockTime[i] != 0, "lock time error");
            nft.safeTransferFrom(msg.sender, address(this), tokenIds[i], 1, "");
            //require(nft.balanceOf(msg.sender, tokenIds[i]) == 1 , "caller not owner");
            uint256 tier = getTier(tokenIds[i]);
            uint256 _baseShare = baseShare[tier];
            uint256 _bonusShare = (_baseShare * bonusSharePercentage[tier])/1000;
            uint256 _timeLockShare = (_baseShare * timeLockBonusPercentage[lockTime[i]])/1000;
            uint256 _totalShare = _baseShare + _bonusShare + _timeLockShare;
            uint256 _lockTime = lockTimes[lockTime[i]];
            uint256 unlockTime = block.timestamp + _lockTime;
            NFTId[tokenIds[i]] = NFTLock(
                msg.sender,
              tokenIds[i],
              _baseShare,
               _bonusShare,
                _timeLockShare,
                 _lockTime,
                  unlockTime,
                   true);

            totalSharesCreated += _totalShare;
            if(totalShares[msg.sender] == 0){
             stakers.push(msg.sender);
             addressIndex[msg.sender] = stakers.length - 1;
            }
            totalShares[msg.sender] += _totalShare;
            stakersNfts[msg.sender].push(tokenIds[i]);

            countPerTier[tier] += 1;
            emit staked(msg.sender, tokenIds[i], _totalShare, unlockTime);
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
             emit withdrawn(tokenIds);
    }

    function extendLock(uint256 nftId, uint256 _newTime) external whenNotPaused nonReentrant{
            require( NFTId[nftId].owner == msg.sender && NFTId[nftId].staked == true, "caller not owner");
            require( NFTId[nftId].lockTime < lockTimes[_newTime] && _newTime <= lockingTimesAvailable, "time error"); 
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
            emit lockExtended(nftId, _newTime);
    }


    function setLockTimes(uint256[] calldata _locktimes, uint256[] calldata _timestamps) external onlyOwner{
        require(_locktimes.length == _timestamps.length, "length mismatched");
        require(lockingTimesAvailable != 0 , "lock time error");
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


    function unlockNfts(uint256[] calldata ids) external onlyOwner{
            for(uint256 i = 0; i < ids.length; i++){
                NFTId[ids[i]].unlockTime = 0;
            }
    }

    function totalStakers() external view returns(uint256){
            return stakers.length;
    }

    function setNFTAddress(address _nftContract)external onlyOwner{
            nft = IERC1155(_nftContract);
    }

    function getTier(uint256 tokenId) public pure returns (uint8) {
    uint8 tier;
    while (tokenId != 0) {
        tier = uint8(tokenId % 10);
        tokenId /= 10;
    }
        return tier;
}

    function getStakersNfts(address _address) external view returns(uint256[] memory){
            uint256[] memory nfts = stakersNfts[_address];
            return nfts;
    }

    function getStakersAddresses() external view returns(address[] memory){   
             return stakers;
    }


    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }


}

