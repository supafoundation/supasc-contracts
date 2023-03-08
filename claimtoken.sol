// SPDX-License-Identifier: UNLICENSED
//events, withdraw function, pause function
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

interface SCTokenContract{ 

function mint(address to, uint256 amount) external;

    }
contract ClaimJuice is AccessControl, ReentrancyGuard {


bytes32 public constant AUTHORIZED_ROLE = keccak256("AUTHORIZED_ROLE");
     bytes32 public constant SIGN_ROLE = keccak256("SIGN_ROLE");

      using ECDSA for bytes32;


    mapping(address=>uint) public currentTotalClaimed;
    uint public totalMinted;
    uint public SCTokenMultiplier;
    uint public totalSupply;
    address public SCTokenAddress;
    address public recipientAddr;
    uint public endRewardsTime;
    uint public totalClaimed;
    uint public maxRewards;
  constructor(){
    //  priceFeed = AggregatorV3Interface(ETHUSDOracle);
        _grantRole(SIGN_ROLE, 0x59D3445a426C3CB6CeBC3033073F5d8ED5BE9fDd);
        recipientAddr=msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUTHORIZED_ROLE, msg.sender);
 
  }
  //time limit, multiplier
  function changeTokenInfo(uint _multiplier, address _tokenAddress, uint _totalSupply, address _recipientAddr) public onlyRole(AUTHORIZED_ROLE) {
      SCTokenMultiplier=_multiplier;
      SCTokenAddress= _tokenAddress;
      totalSupply=_totalSupply;
      recipientAddr=_recipientAddr;
  }
  function changeEndTime(uint _endRewardsTime) public onlyRole(AUTHORIZED_ROLE) {
      endRewardsTime=_endRewardsTime;
  }

  function claimSparks(uint sparksAmount, uint totalUserSparks, uint timestamp, bytes memory sig) public nonReentrant{
        require(block.timestamp<endRewardsTime,"Claim time expired");
        require(verifySignature(sparksAmount,msg.sender, totalUserSparks,timestamp,sig),"Invalid signature provided");
        require(totalUserSparks>currentTotalClaimed[msg.sender],"Already claimed");
        require(timestamp+60>block.timestamp,"Request expired");
        require(totalUserSparks>=currentTotalClaimed[msg.sender]+sparksAmount && sparksAmount>0,"Invalid request");
        require(sparksAmount*SCTokenMultiplier+totalMinted<totalSupply,"Request exceeds total supply");
        currentTotalClaimed[msg.sender]+=sparksAmount;
        totalMinted+=sparksAmount*SCTokenMultiplier;
        SCTokenContract m=SCTokenContract(SCTokenAddress);
          if(totalClaimed+(sparksAmount*SCTokenMultiplier*3/7)+sparksAmount*SCTokenMultiplier>=maxRewards){
            uint base=1000000;
            uint rewards=((maxRewards-totalClaimed)/(base+(base*3/7)))/base;
            totalClaimed=maxRewards;
             m.mint(msg.sender, rewards);
            m.mint(recipientAddr, rewards*3/7);
        }else{
        totalClaimed+=(sparksAmount*SCTokenMultiplier*3/7)+sparksAmount*SCTokenMultiplier;
           m.mint(msg.sender,sparksAmount*SCTokenMultiplier);
        m.mint(recipientAddr,sparksAmount*SCTokenMultiplier*3/7);
        }
   
  }
   function setMaxRewards(uint _maxRewards) public onlyRole(AUTHORIZED_ROLE) {
        maxRewards=_maxRewards;
    }

 function verifySignature(uint sparksAmount, address userAddress, uint totalUserSparks, uint timestamp,bytes memory sig) internal virtual returns (bool) {
       return hasRole(SIGN_ROLE, keccak256(bytes(abi.encodePacked(Strings.toString(sparksAmount),userAddress, Strings.toString(totalUserSparks), Strings.toString(timestamp))))
        .toEthSignedMessageHash()
        .recover(sig));
    }
 function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}