// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract MyERC1155 is ERC1155URIStorage , Ownable, ReentrancyGuard {

    uint8 private constant TIER_1 = 1;
    uint8 private constant TIER_2 = 2;
    uint8 private constant TIER_3 = 3;
    uint8 private constant TIER_4 = 4; 

    mapping(uint256 => uint256) public tokenCounts;
    mapping(uint256 => uint256) private mintPrices;
    mapping(address => uint256) private referReward;
    mapping(address => bool) private isWhitelisted;
    mapping(uint256 => bool) private nftBlacklisted;

    bool whitelistEnabled;
    bool discountEnabled;
    bool isSale;
    bool referEnabled;


    uint256 private raisedCap;
    uint256 private totalSaleCap;
    uint256 private allowedPerMint;
    uint256 private discountPercentage;
    uint256 private referDiscount;
    uint256 private claimPoints;
    //uint256[] public store;

    

    constructor(string memory _uri, uint256 _saleCap) ERC1155(_uri) { 
        totalSaleCap = _saleCap;
    }

    function mint(uint256 tier, uint256 amount, address refferalAddress) public payable nonReentrant {
        
        if(whitelistEnabled){
        require(isWhitelisted[msg.sender] , " Not whiteListed"); 
        }

        if(referEnabled && !discountEnabled){
            require(refferalAddress != msg.sender, "cannot refer your self"); 
            
        }

        require(isSale ,"sale not live");
        require(amount > 0 && amount <= allowedPerMint, "amount Exceed per mint"); 
        require(tier >= 1 && tier <= 4, "Invalid tier");

        uint256 amountToPay;

        if(discountEnabled){
            uint256 discAmount = ((mintPrices[tier]*amount) * discountPercentage)/ 1000;
            amountToPay = (mintPrices[tier]*amount - discAmount);

        }else if(referEnabled){
            uint256 refDiscAmount = ((mintPrices[tier]*amount) * referDiscount)/ 1000;
            amountToPay = (mintPrices[tier]*amount - refDiscAmount);
            if(refferalAddress!= address(0)){
                referReward[refferalAddress] += tier;
            }

        }else{
            amountToPay = mintPrices[tier]*amount;
        }

        require(msg.value == amountToPay, "Insufficient/wrong payment");
        require(msg.value + raisedCap <= totalSaleCap, "cannot mint more");

         uint256 tokenId;

        for(uint256 i=0; i<amount; i++){

            tokenCounts[tier]++;
            tokenId = tokenCounts[tier];
            uint256 id  = tier * 10**uint256(digit(tokenId)) + tokenId;
            //store.push(id);
            
        _mint(msg.sender, id, 1, "");
        }
    }

    function digit(uint256 n) internal pure returns (uint256) {
        uint256 digits = 0;
         while (n != 0) {
         n /= 10;
         digits++;
    }
    return digits;
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

    // function checkIds(address _account, uint16 _tier) public view returns(uint256[] memory){
    //     uint256[] memory ids = _nftIds[_account][_tier];
    //     return ids;
    // }

    function setTokenURI(uint256 _tokenId, string memory _tokenURI) external onlyOwner {
                _setURI( _tokenId, _tokenURI);
    }

    //optional
    //if owner sets tokenURI then this if concat with that uri if set
    function setBaseURI(string memory _baseURI) external onlyOwner{
        _setBaseURI(_baseURI);
    }

    function addWhitelist(address[] memory _whiteListAddress) external onlyOwner {
        for(uint256 i=0; i <= _whiteListAddress.length; i++){
        isWhitelisted[_whiteListAddress[i]] = true;
        }
    }

    function removeWhitelist(address _removeAddress)external onlyOwner {
            isWhitelisted[_removeAddress] = true;
        }

    function blacklistNft(uint256 _nftId) external onlyOwner{
        nftBlacklisted[_nftId] = true;
    }

    function setAllowedPerMint(uint256 _amount) external onlyOwner{
        allowedPerMint = _amount;
    }

    function setDiscountPercentage(uint256 _percentage) external onlyOwner{
        referDiscount = _percentage;
    }

    function setReferalDiscount(uint256 _percentage) external onlyOwner{
        discountPercentage = _percentage;
    }

    function setReferalClaimPoints(uint256 _points) external onlyOwner{
        claimPoints = _points;
    }

    function claimReward() external nonReentrant{
        uint256 usersPoints = referReward[msg.sender];
        require(usersPoints >= claimPoints, "notEnough points");
        referReward[msg.sender] -= claimPoints;
            tokenCounts[1]++;
            uint256 tokenId = tokenCounts[1];
            uint256 id  = 1 * 10**uint256(digit(tokenId)) + tokenId;
            //store.push(id);
            
        _mint(msg.sender, id, 1, "");
    }

}
