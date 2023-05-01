// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract MyERC1155 is ERC1155URIStorage , Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;

    uint256  private constant TIER_1 = 1;
    uint256  private constant TIER_2 = 2;
    uint256  private constant TIER_3 = 3;
    uint256  private constant TIER_4 = 4; 

    mapping(uint256 => uint256) public tokenCounts;
    mapping(uint256 => uint256) public mintPrices;
    mapping(uint256 => uint256) public allowedPerMint;
    mapping(address => uint256) public referReward;
    mapping(address => bool) public isWhitelisted;
    mapping(uint256 => bool) public nftBlacklisted;

    bool public whitelistEnabled;
    bool public discountEnabled;
    bool public isSale;
    bool public referEnabled;


    uint256 public raisedCap;
    uint256 public totalSaleCap;
   // uint256 public allowedPerMint;
    uint256 public discountPercentage;
    uint256 public referDiscount;
    uint256 public claimPoints;
    uint256 public tier4maxCap;

    address  public  operationsAddress;
    address  public treasuryAddress;
    address public paymentToken;

    event nftBlacklistedEvent(uint256 _id); 
    event nftBlacklistRemovedEvent(uint256 _id);
    event whitelistedEvent(address[] _addresses);
    event whitelistRemovedEvent(address[] _addresses);
    event paymentTokenAddedEvent(address _paymentToken);
    event companyAddrAddedEvent(address _operationsAddress, address _treasuryAddress);
    event saleCapEvent(uint256 _cap);
    event allowedPerMintEvent(uint256[] _teirs, uint256[] _amount);
    event discountPercentageEvent(uint256 _percentage); 
    event referPercentageEvent(uint256 _percentage);
    event referClaimPointsEvent(uint256 _points); 
    event tier4CapEvent(uint256 _newCap);
    event mintPricesEvent(uint256[] _teirs, uint256[] _prices);
    event fundsWithdrawn(uint256 _amount);
    event rewardMinted(uint256 _id);
    event toggleSaleEvent(bool);
    event toggleWhitelistEvent(bool);
    event toggleDiscountEvent(bool);
    event toggleReferEvent(bool);
        

     

    constructor(string memory _uri, uint256 _saleCap) ERC1155(_uri) { 
        totalSaleCap = _saleCap;
    }

    function mint(uint256 tier, uint256 amount, address refferalAddress) external nonReentrant {

        require(isSale ,"sale not live");

        if(whitelistEnabled){
        require(isWhitelisted[msg.sender] , " Not whiteListed"); 
        }

        require(amount > 0 && amount <= allowedPerMint[tier], "amount Exceed per mint"); 
        require(tier >= 1 && tier <= 4, "Invalid tier");

        if(tier == 4){
           require(tokenCounts[tier] + amount <= tier4maxCap, "tier 4 cap reached");
        }

        uint256 amountToPay;

        if(discountEnabled){
            uint256 discAmount = ((mintPrices[tier]*amount) * discountPercentage)/ 1000;//100 for 10 percent
            amountToPay = (mintPrices[tier]*amount - discAmount);

        }else if(referEnabled){
            require(refferalAddress != msg.sender, "cannot refer your self");
            uint256 refDiscAmount = ((mintPrices[tier]*amount) * referDiscount)/ 1000;
            amountToPay = (mintPrices[tier]*amount - refDiscAmount);
            if(refferalAddress!= address(0)){
                referReward[refferalAddress] += tier * amount; 
            }

        }else{
            amountToPay = mintPrices[tier]*amount;
        }

        require(amountToPay + raisedCap <= totalSaleCap, "cannot mint more");
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amountToPay);
        raisedCap += amountToPay;

        uint256 tokenId;

        for(uint256 i=0; i<amount; i++){

            tokenCounts[tier]++;
            tokenId = tokenCounts[tier];
            uint256 id  = tier * 10**uint256(digit(tokenId)) + tokenId;
            _mint(msg.sender, id, 1, "");
        }

    }

    function ownerMint(uint256 tier, uint256 amount, address _account) external onlyOwner {

        require(tier >= 1 && tier <= 4, "Invalid tier");

        uint256 tokenId;

        for(uint256 i=0; i<amount; i++){
            tokenCounts[tier]++;
            tokenId = tokenCounts[tier];
            uint256 id  = tier * 10**uint256(digit(tokenId)) + tokenId;
            _mint(_account, id, 1, "");
        }

    }

    function awardReferalPoints(address _account, uint256 _points) external onlyOwner{
        require(_account != address(0) && _points != 0, "null addr or 0 points added");
        referReward[_account] += _points; 
    }



    function digit(uint256 n) internal pure returns (uint256) {
        uint256 digits = 0;
         while (n != 0) {
         n /= 10;
         digits++;
    }
    return digits;
}


    function setMintPrice(uint256[] memory tier, uint256[] memory price) external onlyOwner {
        require(tier.length == price.length && tier.length < 5, "length misMatched");
        for(uint256 i = 0; i < tier.length; i++) {
        require(tier[i] >= 1 && tier[i] <= 4, "Invalid tier");
        mintPrices[tier[i]] = price[i];
        }
        emit mintPricesEvent(tier, price);
    }

    function setTotalSaleCapp(uint256 _newCap) external onlyOwner {
        require(_newCap > totalSaleCap, "Invalid cap");
        totalSaleCap = _newCap;
        emit saleCapEvent(_newCap);
    }
    function currentSupply(uint256 tier) external view returns (uint256) {
        require(tier >= TIER_1 && tier <= TIER_4, "Invalid type ID");
        return tokenCounts[tier];
    }

    function currentTokenId(uint256 tier) external view returns (uint256) {
        require(tier >= TIER_1 && tier <= TIER_4, "Invalid type ID");
            uint256  tokenId = tokenCounts[tier]; 
            uint256 id  = tier * 10**uint256(digit(tokenId)) + tokenId;
            return id ; 
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
            require(_whiteListAddress[i] != address(0), "Cannot add null address");
        isWhitelisted[_whiteListAddress[i]] = true;
        }
        emit whitelistedEvent(_whiteListAddress);
    }

    function removeWhitelist(address[] memory _removeAddresses)external onlyOwner {
        for(uint256 i=0; i < _removeAddresses.length; i++){
            require(_removeAddresses[i] != address(0), "Cannot remove null address");
        isWhitelisted[_removeAddresses[i]] = false;
        }
            emit whitelistRemovedEvent(_removeAddresses);
        }

    function blacklistNft(uint256 _nftId) external onlyOwner{
        require(_nftId != 0, "zero Id");
        nftBlacklisted[_nftId] = true;
        emit nftBlacklistedEvent(_nftId);
    }

    function removeBlacklistedNft(uint256 _nftId) external onlyOwner{
        require(nftBlacklisted[_nftId] == true, "not blacklisted");
        nftBlacklisted[_nftId] = false;
        emit nftBlacklistRemovedEvent(_nftId);
    }

    function setAllowedPerMint(uint256[] memory tier, uint256[] memory amount) external onlyOwner{
            require(tier.length == amount.length && tier.length < 5, "length misMatched");
        for(uint256 i = 0; i < tier.length; i++) {
        require(tier[i] >= 1 && tier[i] <= 4, "Invalid tier");
        allowedPerMint[tier[i]] = amount[i];
        }
        emit allowedPerMintEvent(tier ,amount); 
    }

    function setDiscountPercentage(uint256 _percentage) external onlyOwner{
        require(_percentage != 0, "zero value");
        discountPercentage = _percentage;
        emit discountPercentageEvent(_percentage);
    }

    function setReferalDiscount(uint256 _percentage) external onlyOwner{
        require(_percentage != 0, "zero value");
        referDiscount = _percentage;
        emit referPercentageEvent(_percentage);
        
    }

    function setReferalClaimPoints(uint256 _points) external onlyOwner{
        require(_points != 0, "zero value");
        claimPoints = _points;
        emit referClaimPointsEvent(_points);
    }

    function setTier4MaxCap(uint256 _cap) external onlyOwner{
        require(_cap != 0, "zero value");
        tier4maxCap = _cap; 
        emit tier4CapEvent(_cap);
    }

    function setAddresses(address  _operational, address  _treasury) external onlyOwner{
        require(_operational != address(0) && _treasury != address(0), "null address");
        operationsAddress = _operational;
        treasuryAddress = _treasury;
        emit companyAddrAddedEvent(_operational, _treasury);
    }

    function setPaymentToken(address _paymentToken) external onlyOwner{
        require(_paymentToken != address(0), "null address");
        paymentToken = _paymentToken;
        emit paymentTokenAddedEvent(_paymentToken);
    }

    function toggleSale() external onlyOwner{ 
        isSale = !isSale;
        emit toggleSaleEvent(isSale);
    }

    function toggleWhitelist() external onlyOwner{
        whitelistEnabled = !whitelistEnabled; 
        emit toggleWhitelistEvent(whitelistEnabled);
    }

    function toggleDiscount() external onlyOwner{
        require(discountPercentage != 0,"discount not set");
        discountEnabled = !discountEnabled; 
        emit toggleDiscountEvent(discountEnabled);
    }

    function toggleRefer() external onlyOwner{
        require(referDiscount != 0," refer discount not set");
        referEnabled = !referEnabled; 
        emit toggleReferEvent(referEnabled);
    }

    function withdrawFunds() external onlyOwner{
        uint256 total = IERC20(paymentToken).balanceOf(address(this));
        require(total > 1000, "low funds");
        uint256 treasuryAmount = (total*250)/1000;
        uint256 operationalAmount = (total - treasuryAmount);
        IERC20(paymentToken).safeTransfer(treasuryAddress, treasuryAmount);
        IERC20(paymentToken).safeTransfer(operationsAddress, operationalAmount);
        emit fundsWithdrawn(total);
    }

    function claimReward() external nonReentrant{
        uint256 usersPoints = referReward[msg.sender];
        require(usersPoints >= claimPoints && claimPoints != 0, "notEnough points");
        referReward[msg.sender] -= claimPoints;
            tokenCounts[1]++;
            uint256 tokenId = tokenCounts[1];
            uint256 id  = 1 * 10**uint256(digit(tokenId)) + tokenId;            
        _mint(msg.sender, id, 1, "");
       emit rewardMinted(id);
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
