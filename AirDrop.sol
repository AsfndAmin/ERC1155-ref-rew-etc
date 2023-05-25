// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.17;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AirDrop is Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;
    address public tokenAddress;
    address[] allocated;

    uint256 public totalAmount;
    bool public airDropEnabled;

    struct userClaimData {
        uint256 totalTokens;
        uint256 claimedTokens;
    }

    mapping(address => userClaimData) public userClaim;

        constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    function setAllocations(address[] memory _users, uint256[] memory _totalTokens) public onlyOwner{
        require(!airDropEnabled, "air drop  started"); 
        require(_users.length == _totalTokens.length, "length misMatched");
        for(uint256 i = 0; i < _users.length; i++){
        userClaim[_users[i]].totalTokens += _totalTokens[i];
        userClaim[_users[i]].claimedTokens = 0;
        totalAmount += _totalTokens[i];
        allocated.push(_users[i]);
        }
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
}


    function startAirdrop() public onlyOwner{
        require(!airDropEnabled, "already started");
        require(totalAmount > 0, "allocate first");
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), totalAmount); 
        airDropEnabled = true;

    }

    
    function claimTokens() external nonReentrant {
        require(airDropEnabled, "air drop not started");
        userClaimData storage userData = userClaim[msg.sender];
        require(userData.claimedTokens == 0, "already calimed");
        uint256 withdrawable =  userData.totalTokens;

        require(
            withdrawable > 0 ,
            "nothing to claim"
        );

        userData.claimedTokens = withdrawable;
        IERC20(tokenAddress).safeTransfer(msg.sender, withdrawable); 
    }

    function getUserclaimedTokens(address user) public view returns (uint256) {
        return userClaim[user].claimedTokens;
    }

    function getUserLockedTokens(address user) public view returns (uint256) {
        return userClaim[user].totalTokens - userClaim[user].claimedTokens;
    }

}
