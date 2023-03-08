pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface NFTContract {
    function getLevel(uint256 tokenId) external view returns (uint256);
    function farmRate(uint256 tokenId) external view returns (uint256);
    function setIsStaked(uint256 _tokenId, bool _currentState) external;
}

interface TokenContract {
    function mint(address to, uint256 amount) external;
}

contract ERC721Staking is Initializable, UUPSUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    bytes32 public constant AUTHORIZED_ROLE = keccak256("AUTHORIZED_ROLE");

    event Stake(address indexed staker, uint256 tokenId);
    event Withdraw(address indexed staker, uint256 tokenId);

    // Interfaces for ERC20 and ERC721
    address public rewardsToken;
    IERC721Upgradeable public nftCollection;
    uint public endRewards;
    address public nftContractAddress;
    address public devWallet;
    uint public maxLevel = 2;
    uint public userRate = 6;
    uint public maxRewards;
    uint public totalClaimed;
    mapping(address => uint) public farmRate;

    // Constructor function to set the rewards token and the NFT collection addresses
 function initialize(IERC721Upgradeable _nftCollection, address _rewardsToken) public initializer {
        __ReentrancyGuard_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ERC721Staking_init_unchained(_nftCollection, _rewardsToken);
    }

    function __ERC721Staking_init_unchained(IERC721Upgradeable _nftCollection, address _rewardsToken) internal initializer {
        nftCollection = _nftCollection;
        nftContractAddress = address(_nftCollection);
        rewardsToken = _rewardsToken;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(AUTHORIZED_ROLE, msg.sender);
        devWallet = msg.sender;
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
    struct StakedToken {
        address staker;
        uint256 tokenId;
    }
    
    // Staker info
    struct Staker {
        // Amount of tokens staked by the staker
        uint256 amountStaked;

        // Staked token ids
        StakedToken[] stakedTokens;

        // Last time of the rewards were calculated for this user
        uint256 timeOfLastUpdate;

        // Calculated, but unclaimed rewards for the User. The rewards are
        // calculated each time the user writes to the Smart Contract
        uint256 unclaimedRewards;
    }

    // Rewards per hour per token deposited in wei.
    uint256 private rewardsPerHour = 3600;
//halving
    // Mapping of User Address to Staker info
    mapping(address => Staker) public stakers;

    // Mapping of Token Id to staker. Made for the SC to remeber
    // who to send back the ERC721 Token to.
    mapping(uint256 => address) public stakerAddress;

    // If address already has ERC721 Token/s staked, calculate the rewards.
    // Increment the amountStaked and map msg.sender to the Token Id of the staked
    // Token to later send back on withdrawal. Finally give timeOfLastUpdate the
    // value of now.
    function stake(uint256 _tokenId) external nonReentrant {
        // If wallet has tokens staked, calculate the rewards before adding the new token
        if (stakers[msg.sender].amountStaked > 0) {
            uint256 rewards = calculateRewards(msg.sender);
            stakers[msg.sender].unclaimedRewards += rewards;
        
        }

        // Wallet must own the token they are trying to stake
        require(
            nftCollection.ownerOf(_tokenId) == msg.sender,
            "You must own the token you are trying to stake"
        );
        NFTContract nft = NFTContract(nftContractAddress);
        require(nft.getLevel(_tokenId)>0 && nft.getLevel(_tokenId)<=maxLevel, "Minimum Level 1 required for staking");

        // Create StakedToken
        StakedToken memory stakedToken = StakedToken(msg.sender, _tokenId);

        // Add the token to the stakedTokens array
        stakers[msg.sender].stakedTokens.push(stakedToken);

        // Increment the amount staked for this wallet
        stakers[msg.sender].amountStaked++;
        nft.setIsStaked(_tokenId,true);
        farmRate[msg.sender]+=nft.farmRate(_tokenId)*userRate;
        // Update the mapping of the tokenId to the staker's address

        stakerAddress[_tokenId] = msg.sender;

        // Update the timeOfLastUpdate for the staker   
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
                emit Stake(msg.sender, _tokenId);

    }
    function isStaked(uint tokenId) public view virtual returns(address){
        return stakerAddress[tokenId];
    }
    function modifyRates(uint _userRate)public onlyRole(AUTHORIZED_ROLE) {
       
        userRate=_userRate;
    }
    // Check if user has any ERC721 Tokens Staked and if they tried to withdraw,
    // calculate the rewards and store them in the unclaimedRewards
    // decrement the amountStaked of the user and transfer the ERC721 token back to them
    function withdraw(uint256 _tokenId) external nonReentrant {
        // Make sure the user has at least one token staked before withdrawing
        require(
            stakers[msg.sender].amountStaked > 0,
            "You have no tokens staked"
        );
        
        // Wallet must own the token they are trying to withdraw
        require(stakerAddress[_tokenId] == msg.sender, "You must own the token you are trying to withdraw");

        // Update the rewards for this user, as the amount of rewards decreases with less tokens.
        uint256 rewards = calculateRewards(msg.sender);
        stakers[msg.sender].unclaimedRewards += rewards;

        // Find the index of this token id in the stakedTokens array
        uint256 index = 0;
        for (uint256 i = 0; i < stakers[msg.sender].stakedTokens.length; i++) {
            if (
                stakers[msg.sender].stakedTokens[i].tokenId == _tokenId 
                && 
                stakers[msg.sender].stakedTokens[i].staker != address(0)
            ) {
                index = i;
                break;
            }
        }

        // Set this token's .staker to be address 0 to mark it as no longer staked
        stakers[msg.sender].stakedTokens[index].staker = address(0);
        NFTContract nft = NFTContract(nftContractAddress);
    nft.setIsStaked(_tokenId,false);
        // Decrement the amount staked for this wallet
        stakers[msg.sender].amountStaked-=1;
        farmRate[msg.sender]-=nft.farmRate(_tokenId)*userRate;
    

        // Update the mapping of the tokenId to the be address(0) to indicate that the token is no longer staked
        stakerAddress[_tokenId] = address(0);

        // Transfer the token back to the withdrawer //unlock instead
        
        // Update the timeOfLastUpdate for the withdrawer   
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
                emit Withdraw(msg.sender, _tokenId);

    }

    // Calculate rewards for the msg.sender, check if there are any rewards
    // claim, set unclaimedRewards to 0 and transfer the ERC20 Reward token
    // to the user.
    function claimRewards() external nonReentrant{
        uint256 rewards = calculateRewards(msg.sender) +
            stakers[msg.sender].unclaimedRewards;
        require(rewards > 0, "You have no rewards to claim");
        require(totalClaimed<maxRewards,"NFT Staking rewards maximum limit reached.");
        require(block.timestamp<endRewards,"Claim time expired");
                 TokenContract m=TokenContract(rewardsToken);

        if(totalClaimed+(rewards*3/7)+rewards>=maxRewards){
            uint base=1000000;
            rewards=((maxRewards-totalClaimed)/(base+(base*3/7)))/base;
            totalClaimed=maxRewards;
             m.mint(msg.sender, rewards);
            m.mint(devWallet, rewards*3/7);
        }else{
        totalClaimed+=(rewards*3/7)+rewards;
        m.mint(msg.sender, rewards);
         m.mint(devWallet, rewards*3/7);
        }
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        stakers[msg.sender].unclaimedRewards = 0;
     
        
   
   
        
    }
    function setMaxLevel(uint _maxLevel) public onlyRole(AUTHORIZED_ROLE) {
        maxLevel=_maxLevel;
    }
    function setDevWallet(address _devWallet) public onlyRole(AUTHORIZED_ROLE) {
        devWallet=_devWallet;
    }
    function setMaxRewards(uint _maxRewards) public onlyRole(AUTHORIZED_ROLE) {
        maxRewards=_maxRewards;
    }

    //////////
    // View //
    //////////
     function changeEndTime(uint _endRewards) public onlyRole(AUTHORIZED_ROLE) {
      endRewards=_endRewards;
  }

    function availableRewards(address _staker) public view returns (uint256) {
        uint256 rewards = calculateRewards(_staker) +
            stakers[_staker].unclaimedRewards;
        return rewards;
    }

    function getStakedTokens(address _user) public view returns (StakedToken[] memory) {
        // Check if we know this user
        if (stakers[_user].amountStaked > 0) {
            // Return all the tokens in the stakedToken Array for this user that are not -1
            StakedToken[] memory _stakedTokens = new StakedToken[](stakers[_user].amountStaked);
            uint256 _index = 0;

            for (uint256 j = 0; j < stakers[_user].stakedTokens.length; j++) {
                if (stakers[_user].stakedTokens[j].staker != (address(0))) {
                    _stakedTokens[_index] = stakers[_user].stakedTokens[j];
                    _index++;
                }
            }

            return _stakedTokens;
        }
        
        // Otherwise, return empty array
        else {
            return new StakedToken[](0);
        }
    }

 
    function calculateRewards(address _staker)
        internal
        view
        returns (uint256 _rewards)
    {
        return (((
            ((block.timestamp - stakers[_staker].timeOfLastUpdate) *
                farmRate[_staker])
        ) * rewardsPerHour) / 3600);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}