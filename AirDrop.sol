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
        require(!airDropEnabled, "airdrop started cannot delete now");
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

    }

    
    function claimTokens() external nonReentrant whenNotPaused{
        require(claimStartDate < block.timestamp && claimEndDate > block.timestamp, "air drop not started or ended");
        require(!blackListed[msg.sender], "blacklisted");
        userClaimData storage userData = userClaim[msg.sender];
        require(userData.claimedTokens == 0, "already calimed");
        uint256 withdrawable =  userData.totalTokens;

        require(
            withdrawable > 0 ,
            "nothing to claim"
        );

        userData.claimedTokens = withdrawable;
        IERC20(tokenAddress).safeTransfer(msg.sender, withdrawable); 
        totalClaimed += withdrawable;
    }

    function withdrawAllFunds()external onlyOwner{
       uint256 totalFunds = IERC20(tokenAddress).balanceOf(address(this)); 
       IERC20(tokenAddress).safeTransfer(msg.sender, totalFunds); 
    }

    function changeClaimTime(uint256 startTime, uint256 endTime)external onlyOwner {
        require(startTime < endTime, " time error");
        claimStartDate = startTime;
        claimEndDate = endTime;
    }

    function changeTokenAddress(address token) external onlyOwner{
        require(!airDropEnabled, "airdrop started cannot delete now");
        require(token != address(0), "zero Address");
        tokenAddress = token;
    }

    function adjustRewardAmount(address user, uint256 newAmount, uint256 newTotalShares)external onlyOwner{
            require(!airDropEnabled, "airdrop started cannot delete now");
            uint256 previousAmount = userClaim[user].totalTokens;
            require(previousAmount > 0 , "allocate First");
            userClaim[user].totalTokens = newAmount;
            totalSharesDistributed = newTotalShares;
            if(newAmount > previousAmount){
                totalAmount += (newAmount - previousAmount);
                IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), (newAmount - previousAmount)); 
            }else{
                totalAmount -= (previousAmount - newAmount);
                IERC20(tokenAddress).safeTransfer(msg.sender, (previousAmount - newAmount)); 
            }

    }

    function blackListUser(address account)external onlyOwner{
        blackListed[account] = true;
    }

    function getUserclaimedTokens(address user) public view returns (uint256) {
        return userClaim[user].claimedTokens;
    }

    function getUserLockedTokens(address user) public view returns (uint256) {
        return userClaim[user].totalTokens - userClaim[user].claimedTokens;
    }

}
