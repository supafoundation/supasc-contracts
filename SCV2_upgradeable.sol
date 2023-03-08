pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./BokkyPooBahsDateTimeLibrary.sol";

contract SUPACharge is Initializable, UUPSUpgradeable, AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable {
    using BokkyPooBahsDateTimeLibrary for uint;
    using ECDSAUpgradeable for bytes32;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    bytes32 public constant AUTHORIZED_ROLE = keccak256("AUTHORIZED_ROLE");
    mapping(address => mapping(uint => uint)) public SCTxn;
    address public recipient;
    mapping(address => uint) public referralPoints;
    mapping(address => uint) public isSUPACharged;
    mapping(address => uint) public Sparks;
    mapping(address => uint) public backendNonce;
    mapping(string => bool) public backendReceipt;
    mapping(address => mapping(uint => uint)) public SparksRate;

    function initialize() public initializer {
      __AccessControlEnumerable_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(AUTHORIZED_ROLE, msg.sender);
    recipient = payable(msg.sender);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}


//you do not own
function supachargeWallet(uint durationMonths, address referrer, address paymentMethod) public payable nonReentrant returns(bool){
    require(SCTxn[paymentMethod][durationMonths]!=0,"Invalid payment method");
   IERC20Upgradeable  scpay = IERC20Upgradeable(paymentMethod);
        require(
          scpay.allowance(msg.sender,recipient) >= SCTxn[paymentMethod][durationMonths],
            "Please ensure you have approved the required amount to SUPACharge"
          ); 
    require(referrer!=address(0) && referrer!=msg.sender,"invalid referrer");
   scpay.transferFrom(msg.sender, recipient, SCTxn[paymentMethod][durationMonths]); 
      uint month=BokkyPooBahsDateTimeLibrary.getMonth(block.timestamp);
    uint year=BokkyPooBahsDateTimeLibrary.getYear(block.timestamp);
    uint monthStart=BokkyPooBahsDateTimeLibrary.timestampFromDate(year,month,1);
        uint time=BokkyPooBahsDateTimeLibrary.addMonths(monthStart,1);
   month=BokkyPooBahsDateTimeLibrary.getMonth(time);
    year=BokkyPooBahsDateTimeLibrary.getYear(time);
     monthStart=BokkyPooBahsDateTimeLibrary.timestampFromDate(year,month,1);
    SparksRate[msg.sender][monthStart]+=2;
    Sparks[msg.sender]+=durationMonths*30*86400*2;
    if(referrer!=address(this)){
       //referralDone[msg.sender]=true;//????
      // referralPoints[msg.sender]++;
       referralPoints[referrer]++;
        SparksRate[msg.sender][monthStart]++;
        Sparks[msg.sender]+=durationMonths*30*86400;  
        SparksRate[referrer][monthStart]++;
        Sparks[referrer]+=durationMonths*30*86400;
    }
    if(isSUPACharged[msg.sender]==0 || isSUPACharged[msg.sender]<=block.timestamp){
    isSUPACharged[msg.sender]=BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp,durationMonths);
    }else{
      isSUPACharged[msg.sender]=isSUPACharged[msg.sender]-block.timestamp+BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp,durationMonths);
    }


     

        return true;
        }

 function manualSUPACharge(uint durationMonths, address walletAddress, address referrer) public onlyRole(AUTHORIZED_ROLE) nonReentrant returns(bool){
          require(referrer!=address(0) && referrer!=msg.sender,"invalid referrer");

      uint month=BokkyPooBahsDateTimeLibrary.getMonth(block.timestamp);
    uint year=BokkyPooBahsDateTimeLibrary.getYear(block.timestamp);
    uint monthStart=BokkyPooBahsDateTimeLibrary.timestampFromDate(year,month,1);
        uint time=BokkyPooBahsDateTimeLibrary.addMonths(monthStart,1);
   month=BokkyPooBahsDateTimeLibrary.getMonth(time);
    year=BokkyPooBahsDateTimeLibrary.getYear(time);
     monthStart=BokkyPooBahsDateTimeLibrary.timestampFromDate(year,month,1);
    SparksRate[walletAddress][monthStart]+=2;
    Sparks[walletAddress]+=durationMonths*30*86400*2;
 if(referrer!=address(this)){
      // referralDone[walletAddress]=true;
       //referralPoints[walletAddress]++;
       referralPoints[referrer]++;
        SparksRate[walletAddress][monthStart]++;
        Sparks[walletAddress]+=durationMonths*30*86400;  
        SparksRate[referrer][monthStart]++;
        Sparks[referrer]+=durationMonths*30*86400;
    }
    if(isSUPACharged[walletAddress]==0 || isSUPACharged[walletAddress]<=block.timestamp){
    isSUPACharged[walletAddress]=BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp,durationMonths);
    }else{
      isSUPACharged[walletAddress]=isSUPACharged[walletAddress]-block.timestamp+BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp,durationMonths);
    }
return true;

 }

 function backendSUPACharge(uint durationMonths, address referrer, address walletAddress, uint nonce, string memory receipt) onlyRole(AUTHORIZED_ROLE) nonReentrant public returns(bool){
       require(referrer!=address(0) && referrer!=msg.sender,"invalid referrer");
       require(backendNonce[walletAddress]<nonce && backendReceipt[receipt]==false,"Already claimed");
       backendNonce[walletAddress]=nonce;
       backendReceipt[receipt]=true;
      uint month=BokkyPooBahsDateTimeLibrary.getMonth(block.timestamp);
    uint year=BokkyPooBahsDateTimeLibrary.getYear(block.timestamp);
    uint monthStart=BokkyPooBahsDateTimeLibrary.timestampFromDate(year,month,1);
        uint time=BokkyPooBahsDateTimeLibrary.addMonths(monthStart,1);
   month=BokkyPooBahsDateTimeLibrary.getMonth(time);
    year=BokkyPooBahsDateTimeLibrary.getYear(time);
     monthStart=BokkyPooBahsDateTimeLibrary.timestampFromDate(year,month,1);
    SparksRate[walletAddress][monthStart]+=2;
    Sparks[walletAddress]+=durationMonths*30*86400*2;
 if(referrer!=address(this)){
       //referralDone[walletAddress]=true;
       //referralPoints[walletAddress]++;
       referralPoints[referrer]++;
        SparksRate[walletAddress][monthStart]++;
        Sparks[walletAddress]+=durationMonths*30*86400;  
        SparksRate[referrer][monthStart]++;
        Sparks[referrer]+=durationMonths*30*86400;
    }
    if(isSUPACharged[walletAddress]==0 || isSUPACharged[walletAddress]<=block.timestamp){
    isSUPACharged[walletAddress]=BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp,durationMonths);
    }else{
      isSUPACharged[walletAddress]=isSUPACharged[walletAddress]-block.timestamp+BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp,durationMonths);
    }

return true;
 }


 function getUpcomingSparksRate(address walletAddress) public view returns(uint){
    uint rate;
    for(uint i=0; i<12;i++){
        uint timestamp=BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp,1);
        uint newTimestamp=BokkyPooBahsDateTimeLibrary.subMonths(timestamp,i);
        uint month=BokkyPooBahsDateTimeLibrary.getMonth(newTimestamp);
        uint year=BokkyPooBahsDateTimeLibrary.getYear(newTimestamp);
        uint monthStart=BokkyPooBahsDateTimeLibrary.timestampFromDate(year,month,1);
        rate+=SparksRate[walletAddress][monthStart];
    }
    return rate;
    }
      function getSparksRate(address walletAddress) public view returns(uint){
    uint rate;
    for(uint i=0; i<12;i++){
        uint newTimestamp=BokkyPooBahsDateTimeLibrary.subMonths(block.timestamp,i);
        uint month=BokkyPooBahsDateTimeLibrary.getMonth(newTimestamp);
        uint year=BokkyPooBahsDateTimeLibrary.getYear(newTimestamp);
        uint monthStart=BokkyPooBahsDateTimeLibrary.timestampFromDate(year,month,1);
        rate+=SparksRate[walletAddress][monthStart];
    }
    return rate;
    }
function getIsSUPACharged(address userAddress) public view virtual returns(uint){

    return isSUPACharged[userAddress];
}
    function getFragments(address userAddress)public view virtual returns(uint){

    return referralPoints[userAddress];
}
  function setPrice(uint _durationMonths, uint _USDPrice, address contractAddress) public onlyRole(AUTHORIZED_ROLE) returns(bool){
      SCTxn[contractAddress][_durationMonths]=_USDPrice;
    return true;
  }

    function changeRecipient(address _recipient) public onlyRole(AUTHORIZED_ROLE) returns(bool){
      recipient=payable(_recipient);
      return true;
  }  
 function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
   




