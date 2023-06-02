// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.17;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract AirDrop is Ownable, ReentrancyGuard, Pausable {

    using SafeERC20 for IERC20;
    address public tokenAddress;
    address[] allocated;

    uint256 public totalAmount;
    uint256 public totalClaimed;
    uint256 public totalSharesDistributed;
    uint256 public claimStartDate;
    uint256 public claimEndDate;
    bool public airDropEnabled;

    struct userClaimData {
        uint256 totalTokens;
        uint256 claimedTokens;
    }

    mapping(address => userClaimData) public userClaim;
    mapping(address => bool) public blackListed;

    event rewardClaimed(address _user, uint256 _amount);
    event claimPeriodChanged(uint256 _startTime, uint256 _endTime);
    event fundsDeposited(uint256 _amount);
    event FundsWithdrawn(uint256 _amount);
    event blacklisted(address _user, bool _is);
    event removedBlacklisted(address _user, bool _is);

        constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    function setAllocations(address[] memory _users, uint256[] memory _totalTokens, uint256 _totalSharesDistributed) public onlyOwner{
        require(!airDropEnabled, "air drop  started"); 
        require(_users.length == _totalTokens.length, "length misMatched");
        for(uint256 i = 0; i < _users.length; i++){
        userClaim[_users[i]].totalTokens += _totalTokens[i];
        userClaim[_users[i]].claimedTokens = 0;
        totalAmount += _totalTokens[i];
        allocated.push(_users[i]);
        }
        totalSharesDistributed += _totalSharesDistributed;
    }

        //to auto remove all allocations
    function removeAllAllocations() public onlyOwner {
    for (uint256 i = 0; i < allocated.length; i++) {
        address user = allocated[i];
        userClaim[user].totalTokens = 0;
        userClaim[user].claimedTokens = 0;
    }
    totalAmount = 0;
    totalSharesDistributed = 0;
    delete allocated;
}


    function startAirdrop(uint256 startTime, uint256 endTime) public onlyOwner{
        require(!airDropEnabled, "already started");
        require(totalAmount > 0, "allocate first");
        require(startTime < endTime, " time error");
        claimStartDate = startTime;
        claimEndDate = endTime;
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), totalAmount); 
        airDropEnabled = true;
        emit fundsDeposited(totalAmount);

    }

    
    function claimTokens() external nonReentrant whenNotPaused{
        require(claimStartDate < block.timestamp && claimEndDate > block.timestamp, "air drop not started or ended");
        require(!blackListed[msg.sender], "blacklisted");
        userClaimData storage userData = userClaim[msg.sender];
        uint256 withdrawable =  userData.totalTokens;
        uint256 availableTokens = withdrawable - userData.claimedTokens; 
        require(availableTokens  > 0, "nothing to claim");

        userData.claimedTokens += availableTokens;
        IERC20(tokenAddress).safeTransfer(msg.sender, availableTokens); 
        totalClaimed += availableTokens;
        emit rewardClaimed(msg.sender, availableTokens);
    }

    function withdrawAllFunds()external onlyOwner{
       uint256 totalFunds = IERC20(tokenAddress).balanceOf(address(this)); 
       IERC20(tokenAddress).safeTransfer(msg.sender, totalFunds); 
       emit FundsWithdrawn(totalFunds);
    }

    function changeClaimTime(uint256 startTime, uint256 endTime)external onlyOwner {
        require(startTime < endTime, " time error");
        claimStartDate = startTime;
        claimEndDate = endTime;
        emit claimPeriodChanged(startTime, endTime);
    }

    function changeTokenAddress(address token) external onlyOwner{
        require(!airDropEnabled, "airdrop started cannot delete now");
        require(token != address(0), "zero Address");
        tokenAddress = token;
    }

    function adjustRewardAmount(address user, uint256 newAmount, uint256 newTotalShares)external onlyOwner{
            require(!airDropEnabled, "airdrop started cannot adjust now");
            uint256 previousAmount = userClaim[user].totalTokens;
            require(previousAmount > 0 , "allocate First");
            userClaim[user].totalTokens = newAmount;
            totalSharesDistributed = newTotalShares;
            if(newAmount > previousAmount){
                totalAmount += (newAmount - previousAmount);               
            }else{
                totalAmount -= (previousAmount - newAmount);
               
            }
    }

    function setTotalSharesDistributed(uint256 newTotalShares)external onlyOwner{
            totalSharesDistributed = newTotalShares;
    }

    function blackListUser(address account)external onlyOwner{
        blackListed[account] = true;
        emit blacklisted(account , true);
    }

      function removeBlackListUser(address account)external onlyOwner{
          require(blackListed[account], "not blacklisted");
        blackListed[account] = false;
        emit removedBlacklisted(account , false);
    }

    function getUserclaimedTokens(address user) public view returns (uint256) {
        return userClaim[user].claimedTokens;
    }

    function getUserLockedTokens(address user) public view returns (uint256) {
        return userClaim[user].totalTokens - userClaim[user].claimedTokens;
    }

}
