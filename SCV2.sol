pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./BokkyPooBahsDateTimeLibrary.sol";

contract SUPAChargeRegular is AccessControl, ReentrancyGuard {
    using BokkyPooBahsDateTimeLibrary for uint;
      using ECDSA for bytes32;
using Counters for Counters.Counter;
bytes32 public constant AUTHORIZED_ROLE = keccak256("AUTHORIZED_ROLE");
    mapping(address=>mapping(uint=>uint)) public SCTxn;
    address public recipient;
 //mapping(address=>bool) public referralDone;
 mapping(address=>uint) public referralPoints;
 mapping(address=>uint) public isSUPACharged;
      mapping(address=>uint) public Sparks;
      mapping(address=>uint) public backendNonce;
      mapping(string=>bool) public backendReceipt;
      mapping(address=>mapping(uint=>uint)) public SparksRate;
  constructor(){
    //  priceFeed = AggregatorV3Interface(ETHUSDOracle);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUTHORIZED_ROLE, msg.sender);
        recipient=payable(msg.sender);
 
  }
//you do not own
function supachargeWallet(uint durationMonths, address referrer, address paymentMethod) public payable returns(bool){
    require(SCTxn[paymentMethod][durationMonths]!=0,"Invalid payment method");
   IERC20  scpay = IERC20(paymentMethod);
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

 function manualSUPACharge(uint durationMonths, address walletAddress, address referrer) public onlyRole(AUTHORIZED_ROLE) returns(bool){
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

 function backendSUPACharge(uint durationMonths, address referrer, address walletAddress, uint nonce, string memory receipt) onlyRole(AUTHORIZED_ROLE) public returns(bool){
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
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}