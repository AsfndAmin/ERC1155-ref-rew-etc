//SPDX-License-identifier: MIT
pragma solidity ^0.8.0;
 
 import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
 import "@openzeppelin/contracts/utils/Counters.sol";

 contract MultipleTokens is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenids;
 //   uint256 public constant token1 = 0;
  //  uint256 public constant token2 = 1;
 //   uint256 public constant token3 = 2;
 //   uint256 public constant token4 = 5;
   uint256 mintingLimit = 100;
 //   string public _baseURI = baseURI_;
    //uint256 _tokenUri;
    constructor(string memory baseURI_) ERC1155(baseURI_){
  //     require( _balances[id][msg.sender]<= mintingLimit);
  //     _mint(msg.sender,token1,50,"");
      // _mint(msg.sender,token2,50,"");
      // _mint(msg.sender,token3,50,"");
      // _mint(msg.sender,token4,50,"");
       
    }
    function mintTokens( uint256  amount, bytes memory data) external{
       require(msg.sender != address(0));
   
       
       uint256 id = _tokenids.current();
       require(balanceOf(msg.sender , id) + amount <= mintingLimit);
       _tokenids.increment();
  //      
        _mint(msg.sender, id, amount ,data);

    }
    function batchMint(address _to, uint256[] memory _amounts)external{
  //     for(uint256 i=0 , i < ids.length ,i++){
     uint256[] memory idsValues = new uint256[](_amounts.length) ; 
     for(uint256  i=0 ; i < _amounts.length ; i++){
           idsValues[i] = _tokenids.current();
           _tokenids.increment();
     }
     _mintBatch(_to, idsValues , _amounts , "");
         
