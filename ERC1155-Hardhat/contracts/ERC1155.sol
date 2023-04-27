// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract MyERC1155 is ERC1155URIStorage , Ownable, ReentrancyGuard {

    uint256  private constant TIER_1 = 1;
    uint256  private constant TIER_2 = 2;
    uint256  private constant TIER_3 = 3;
    uint256  private constant TIER_4 = 4; 

    mapping(uint256 => uint256) public tokenCounts;
    mapping(uint256 => uint256) public mintPrices;
    mapping(address => uint256) public referReward;
    mapping(address => bool) public isWhitelisted;
    mapping(uint256 => bool) public nftBlacklisted;

    bool public whitelistEnabled;
    bool public discountEnabled;
    bool public isSale;
    bool public referEnabled;


    uint256 public raisedCap;
    uint256 public totalSaleCap;
    uint256 public allowedPerMint;
    uint256 public discountPercentage;
    uint256 public referDiscount;
    uint256 public claimPoints;
    //uint256[] public store;

    address payable public  operationsAddress;
    address payable public treasuryAddress;

    

    constructor(string memory _uri, uint256 _saleCap) ERC1155(_uri) { 
        totalSaleCap = _saleCap;
    }

    function mint(uint256 tier, uint256 amount, address refferalAddress) public payable nonReentrant {


        require(isSale ,"sale not live");

        if(whitelistEnabled){
        require(isWhitelisted[msg.sender] , " Not whiteListed"); 
        }

        require(amount > 0 && amount <= allowedPerMint, "amount Exceed per mint"); 
        require(tier >= 1 && tier <= 4, "Invalid tier");

        uint256 amountToPay;

        if(discountEnabled){
            uint256 discAmount = ((mintPrices[tier]*amount) * discountPercentage)/ 1000;//100 for 10 percent
            amountToPay = (mintPrices[tier]*amount - discAmount);

        }else if(referEnabled){
            require(refferalAddress != msg.sender, "cannot refer your self");
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


    function setMintPrice(uint256[] memory tier, uint256[] memory price) public onlyOwner {
        require(tier.length == price.length && tier.length < 5, "length misMatched");
        for(uint256 i = 0; i < tier.length; i++) {
        require(tier[i] >= 1 && tier[i] <= 4, "Invalid tier");
        mintPrices[tier[i]] = price[i];
        }
    }

    function setTotalSaleCapp(uint256 _newCap) public onlyOwner {
        require(_newCap > totalSaleCap, "Invalid cap");
        totalSaleCap = _newCap;
    }
    function currentSupply(uint256 tier) external view returns (uint256) {
        require(tier >= TIER_1 && tier <= TIER_4, "Invalid type ID");
        return tokenCounts[tier];
    }

    function getTotalEthRaised() public view returns (uint256) {
        return raisedCap;
    }


    function setTokenURI(uint256 _tokenId, string memory _tokenURI) external onlyOwner {
                _setURI( _tokenId, _tokenURI);
    }

    //optional
    //if owner sets tokenURI then this if concat with that uri if set
    function setBaseURI(string memory _baseURI) external onlyOwner{
        _setBaseURI(_baseURI);
    }

    function addWhitelist(address[] memory _whiteListAddress) external onlyOwner {
        for(uint256 i=0; i < _whiteListAddress.length; i++){
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

    function setAddresses(address payable _operational, address payable _treasury) external onlyOwner{
        operationsAddress = _operational;
        treasuryAddress = _treasury;
    }

    function toggleSale() external onlyOwner{ 
        isSale = !isSale;
    }

    function toggleWhitelist() external onlyOwner{
        whitelistEnabled = !whitelistEnabled; 
    }

    function toggleDiscount() external onlyOwner{
        discountEnabled = !discountEnabled; 
    }

    function toggleRefer() external onlyOwner{
        referEnabled = !referEnabled; 
    }

    function withdrawFunds() external onlyOwner{
        uint256 total = address(this).balance;
        require(total > 1000, "low funds");
        uint256 treasuryAmount = (total*250)/1000;
        uint256 operationalAmount = (total - treasuryAmount);
        treasuryAddress.transfer(treasuryAmount);
        operationsAddress.transfer(operationalAmount);
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

      /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        require(!nftBlacklisted[id], "Blacklisted");
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
         for (uint256 i = 0; i < ids.length; i++) {
             require(!nftBlacklisted[ids[i]], "Blacklisted");
         }
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

}
