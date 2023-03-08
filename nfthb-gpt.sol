// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface SUPAChargeContract {
    function getIsSUPACharged(address userAddress) external view returns(uint);
    function getFragments(address userAddress) external view returns(uint);
}

contract HumbleBeginnings is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable, ERC721Burnable, ReentrancyGuard {
    using Counters for Counters.Counter;
    string private base = "https://bucket.supa.foundation/cards/json/";

    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _tokenIdL1Counter;
    Counters.Counter private _tokenIdL2Counter;
    mapping(address => bool) public userMinted;
    mapping(address => bool) public claimedL1;
    mapping(address => bool) public claimedL2;
    mapping(uint => uint) public level;
    mapping(uint => uint) public farmRate;
    address public supachargeContractAddress;
    address public stakingContractAddress;
    uint public mintSizeL1;
    uint public mintSizeL2;
    mapping(uint => bool) isStaked;

    constructor(address _supachargeContractAddress, uint _mintSizeL1, uint _mintSizeL2) ERC721("HumbleBeginnings", "SCHB") {
        supachargeContractAddress = _supachargeContractAddress;
        mintSizeL1 = _mintSizeL1;
        mintSizeL2 = _mintSizeL2;
    }

    function changeParams(address _stakingContractAddress, address _supachargeContractAddress, uint _mintSizeL1, uint _mintSizeL2) public onlyOwner {
        stakingContractAddress = _stakingContractAddress;
        supachargeContractAddress = _supachargeContractAddress;
        mintSizeL1 = _mintSizeL1;
        mintSizeL2 = _mintSizeL2;
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
   function mintLevelZero(string memory randomString) public nonReentrant returns (bool success) {
    require(userMinted[msg.sender] == false, "You already claimed your free NFT");
    userMinted[msg.sender] = true;
    _tokenIdCounter.increment();
    _safeMint(msg.sender, _tokenIdCounter.current());
    bytes32 hashKeccak = keccak256(abi.encodePacked(randomString));
    hashKeccak = keccak256(abi.encodePacked(hashKeccak));
    uint rng1 = randomize(hashKeccak, 100) + 1;
    _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked('0-', Strings.toString(rng1), '.json')));
    level[_tokenIdCounter.current()] = 0;
    return true;
}

    function getLevel(uint tokenId) public view virtual returns(uint){
        return level[tokenId];
    }

    function getFarmRate(uint tokenId)public view virtual returns(uint){
        return farmRate[level[tokenId]];
    }

    function setFarmRate(uint _level, uint _farmRate) public onlyOwner {
        farmRate[_level] = _farmRate;
    }

    function setIsStaked(uint _tokenId, bool _currentState) public nonReentrant {
        require(msg.sender == stakingContractAddress, "No Permission");
        isStaked[_tokenId] = _currentState;
    }

    function upgradeToOne(uint tokenId) public nonReentrant returns(bool success) {
        require(_tokenIdL1Counter.current() + 1 <= mintSizeL1, "Mint limit reached");
        require(ownerOf(tokenId) == msg.sender, "You don't own this NFT!");
        require(level[tokenId] == 0, "Not the correct level");
        require(isStaked[tokenId] == false, "Currently Staked");
        require(claimedL1[msg.sender] == false, "Already claimed Level 1 Card");

        SUPAChargeContract sc = SUPAChargeContract(supachargeContractAddress);
        require(sc.getIsSUPACharged(msg.sender) > block.timestamp, "Not SUPACharged");
        require(sc.getFragments(msg.sender) >= 2, "Insufficient fragments to upgrade");

        level[tokenId] = 1;
        _tokenIdL1Counter.increment();
        claimedL1[msg.sender] = true;

        _setTokenURI(tokenId, string(abi.encodePacked('1-', Strings.toString(_tokenIdL1Counter.current()), '.json')));
    }

    function upgradeToTwo(uint tokenId) public nonReentrant returns(bool success) {
        require(_tokenIdL2Counter.current() + 1 <= mintSizeL2, "Mint limit reached");
        require(ownerOf(tokenId) == msg.sender, "You don't own this NFT!");
        require(level[tokenId] == 1, "Not the correct level");
        require(isStaked[tokenId] == false, "Currently Staked");

        SUPAChargeContract sc = SUPAChargeContract(supachargeContractAddress);
        require(sc.getFragments(msg.sender) >= 5, "Insufficient fragments to upgrade");
        require(claimedL2[msg.sender] == false, "Already claimed Level 2 Card");
        require(sc.getIsSUPACharged(msg.sender) > block.timestamp, "Not SUPACharged");
        claimedL2[msg.sender] = true;

        _tokenIdL2Counter.increment();
        level[tokenId] = 2;
        _setTokenURI(tokenId, string(abi.encodePacked('2-', Strings.toString(_tokenIdL2Counter.current()), '.json')));
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
    override(ERC721, ERC721Enumerable)
{
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
    require(isStaked[tokenId] == false, "Currently Staked");
}

function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
}

function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
{
    return super.tokenURI(tokenId);
}

function randomize(bytes32 hash, uint range) private view returns (uint) {
    // sha3 and now have been deprecated
    return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, msg.sender, hash))) % range;
    // convert hash to integer
    // players is an array of entrants
}

function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
{
    return super.supportsInterface(interfaceId);
}
}