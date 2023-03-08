// SPDX-License-Identifier: UNLICENSED
//event
pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";


interface SUPAChargeContract{
function getIsSUPACharged(address userAddress) external view returns(uint);
function getFragments(address userAddress) external view returns(uint);
}

contract HumbleBeginnings is Initializable, OwnableUpgradeable, PausableUpgradeable, ERC721URIStorageUpgradeable, ERC721EnumerableUpgradeable, ERC721BurnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
using CountersUpgradeable for CountersUpgradeable.Counter;
using StringsUpgradeable for uint256;
string private base = "https://bucket.supa.foundation/cards/json/";
CountersUpgradeable.Counter private _tokenIdCounter;
CountersUpgradeable.Counter private _tokenIdL1Counter;
CountersUpgradeable.Counter private _tokenIdL2Counter;
mapping(address=>bool) public userMinted;
mapping(address=>bool) public claimedL1;
mapping(address=>bool) public claimedL2;
mapping(uint=>uint) public  level;
mapping(uint=>uint) public farmRate;
mapping(uint=>bool) isStaked;

address public supachargeContractAddress;
address public stakingContractAddress;
uint public mintSizeL1;
uint public mintSizeL2;

function initialize(address _supachargeContractAddress, uint _mintSizeL1, uint _mintSizeL2) public initializer {
    __ERC721URIStorage_init();
    __ERC721Enumerable_init();
    __Pausable_init();
    __Ownable_init();
    __ERC721Burnable_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();

    supachargeContractAddress=_supachargeContractAddress;
    mintSizeL1=_mintSizeL1;
    mintSizeL2= _mintSizeL2;
}

function _authorizeUpgrade(address) internal override onlyOwner {}
    function changeParams(address _stakingContractAddress, address _supachargeContractAddress, uint _mintSizeL1, uint _mintSizeL2) public onlyOwner{
          stakingContractAddress=_stakingContractAddress;
            supachargeContractAddress=_supachargeContractAddress;
      

            mintSizeL1=_mintSizeL1;
            mintSizeL2= _mintSizeL2;
    }
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
   function mintLevelZero(string memory randomString) public nonReentrant returns (bool success){
    //check string length?
      require(userMinted[msg.sender]==false,"You already claimed your free NFT");
        userMinted[msg.sender]=true;
         _tokenIdCounter.increment();
         _safeMint(msg.sender, _tokenIdCounter.current());
          bytes32  hashKeccak=keccak256(abi.encodePacked(randomString));
        hashKeccak=keccak256(abi.encodePacked(hashKeccak));
        uint rng1=randomize(hashKeccak,100)+1;
    _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked('0-',StringsUpgradeable.toString(rng1), '.json')));
    level[_tokenIdCounter.current()]=0;
         return true;
    }
    function getLevel(uint tokenId) public view virtual returns(uint){
        return level[tokenId];
    }
    function getFarmRate(uint tokenId)public view virtual returns(uint){
      
        return farmRate[level[tokenId]];
    }
    function setFarmRate(uint _level, uint _farmRate) public onlyOwner{
        farmRate[_level]=_farmRate;
    }
    function setIsStaked(uint _tokenId, bool _currentState) public nonReentrant{
        require(msg.sender==stakingContractAddress,"No Permission");
        isStaked[_tokenId]=_currentState;
    }
    function upgradeToOne(uint tokenId) public nonReentrant returns(bool success){
        require(_tokenIdL1Counter.current() + 1 <= mintSizeL1, "Mint limit reached");
   require(
            ownerOf(tokenId) == msg.sender,
            "You don't own this NFT!"
        );
    require(level[tokenId]==0,"Not the correct level");
        require(isStaked[tokenId]==false,"Currently Staked");
      require(claimedL1[msg.sender]==false,"Already claimed Level 1 Card");
      SUPAChargeContract sc=SUPAChargeContract(supachargeContractAddress);
      require(sc.getIsSUPACharged(msg.sender)>block.timestamp,"Not SUPACharged");
       require(sc.getFragments(msg.sender)>=2,"Insufficient fragments to upgrade");
    level[tokenId]=1;
      _tokenIdL1Counter.increment();
      claimedL1[msg.sender]=true;
    _setTokenURI(tokenId, string(abi.encodePacked('1-',StringsUpgradeable.toString(_tokenIdL1Counter.current()), '.json')));
    
    }

    function upgradeToTwo(uint tokenId) public nonReentrant returns(bool success){
                require(_tokenIdL2Counter.current() + 1 <= mintSizeL2, "Mint limit reached");
 require(
            ownerOf(tokenId) == msg.sender,
            "You don't own this NFT!"
        );
    require(level[tokenId]==1,"Not the correct level");

        require(isStaked[tokenId]==false,"Currently Staked");
      SUPAChargeContract sc=SUPAChargeContract(supachargeContractAddress);

      require(sc.getFragments(msg.sender)>=5,"Insufficient fragments to upgrade");
      require(claimedL2[msg.sender]==false,"Already claimed Level 2 Card");
      require(sc.getIsSUPACharged(msg.sender)>block.timestamp,"Not SUPACharged");
      claimedL2[msg.sender]=true;
        _tokenIdL2Counter.increment();
        level[tokenId]=2;
        
    _setTokenURI(tokenId, string(abi.encodePacked('2-',StringsUpgradeable.toString(_tokenIdL2Counter.current()), '.json')));

    }
   

    // The following functions are overrides required by Solidity.

  


 function _baseURI() internal view override returns (string memory) {
    return base;
    }
  function setBaseURI(string memory _base) public onlyOwner {
     
    base = _base;
   
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
                require(isStaked[tokenId]==false,"Currently Staked");

    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
     function randomize(bytes32 hash, uint range) private view returns (uint) {
        // sha3 and now have been deprecated
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, msg.sender, hash)))% range;
        // convert hash to integer
        // players is an array of entrants
        
    }
 function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    returns (bool)
{
    return super.supportsInterface(interfaceId);
}
    
}