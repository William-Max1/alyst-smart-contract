pragma solidity ^0.8.15;


import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// @audit: I suggest using openzeppelin IERC20 instead. But this is alright!
interface NOTEInterface {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}


interface Turnstile {
    function assign(uint256) external returns(uint256);
}
//@audit: please add some events for log. This helps to debug and keep trace of them
contract AlystCampaign is AccessControl ,ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string public campaignName;
    string private campaignNFTURI;
    uint public campaignTargetAmount;
    uint public campaignFundedAmount;
    uint public campaignPeriod;
    uint public campaignTimeOpen;
    address public campaignCreator;

    address[] public pledgers;

    address public NOTEAddress = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    NOTEInterface NOTE = NOTEInterface(NOTEAddress);

    // address alystTreasury = 0xE7f6F39B0A2b5Adf22A4ebc8105AF443086547c9;
    Turnstile turnstile = Turnstile(0xEcf044C5B4b867CFda001101c617eCd347095B44);


    mapping(address => uint) public userToPledgeAmount;
    mapping(address => bool) public userHasPledged;//@audit: mapping of bool consumes large amount of gas, use mapping to uint256, `0` for false and `1` for true


    constructor(string memory _campaignName, 
                string memory _campaignSymbol, 
                string memory _campaignURI,
                uint _campaignTargetAmount, 
                uint _campaignPeriod,
                uint256 _csrID
                ) ERC721(_campaignName, _campaignSymbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, campaignCreator);
        campaignNFTURI = _campaignURI;
        campaignName = _campaignName;
        campaignTargetAmount = _campaignTargetAmount;
        campaignPeriod = _campaignPeriod;
        campaignTimeOpen = block.timestamp;
        turnstile.assign(_csrID);
    }
//@audit: using custom errors is better(gas saving)
    modifier onlyAdmin() {
    require(isAdmin(msg.sender), "Restricted to admins.");
    _;
  }
// @audit: I suggest adding `nonReentrant` to this function
    function pledgeToCampaign(uint _amount) public {
        require(_amount > 0);// @audit: please cache _amount to save gas
        NOTE.transferFrom(msg.sender, address(this), _amount);// @audit: use `safetransferFrom` instead

        if (!userHasPledged[msg.sender]) {
             pledgers.push(msg.sender);
        }
        userHasPledged[msg.sender] = true;
        // @audit:(severe issue)I think this shoud be `+=`, when a msg.sender has a campaign and add more fund, this may be wrong. (Though he can refund and then pledge again)
        userToPledgeAmount[msg.sender] = _amount;
        campaignFundedAmount = campaignFundedAmount + _amount;

    }
// @audit: I suggest adding `nonReentrant` to this function
    function mintProofOfPledge() public returns (uint) {
        require(block.timestamp > campaignTimeOpen + campaignPeriod);
        require(campaignFundedAmount == campaignTargetAmount || campaignFundedAmount > campaignTargetAmount);
        require(userHasPledged[msg.sender] == true);//@audit: use `require(userHasPledged[msg.sender])` instead

        _tokenIds.increment();

         uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, campaignNFTURI);

        return newItemId;

    }

// @audit: I suggest adding `nonReentrant` to this function
    function refund() public {   
        require(block.timestamp > campaignTimeOpen + campaignPeriod);
        require(campaignTargetAmount != campaignFundedAmount);
        require(userToPledgeAmount[msg.sender] > 0);
        
        // check amount invested 
        uint refundAmount = userToPledgeAmount[msg.sender];
        userToPledgeAmount[msg.sender] = 0;
        NOTE.transferFrom(address(this), msg.sender, refundAmount);// @audit: use `transfer` instead

        
    }

    function withdraw(address _campaignTreasury) public onlyAdmin {
       require(block.timestamp > campaignTimeOpen + campaignPeriod);
       require(campaignFundedAmount == campaignTargetAmount || campaignFundedAmount > campaignTargetAmount);

       // uint alystServiceCharge = address(this).balance * 3 / 200  ;
       // uint projectFund = address(this).balance - alystServiceCharge;

       uint noteContractBalance = NOTE.balanceOf(address(this));

       NOTE.transferFrom(address(this), _campaignTreasury, noteContractBalance);// @audit: use `transfer` instead. not transferfrom

        // NOTE.transferFrom(address(this), _campaignTreasury, projectFund);
        // NOTE.transferFrom(address(this), alystTreasury, alystServiceCharge);

    }

    function setCampaignNFTURI(string memory _nftURI) public onlyAdmin {
        campaignNFTURI = _nftURI;

    }

    function isAdmin(address account) public virtual view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return(
        ERC721.supportsInterface(interfaceId) || 
        AccessControl.supportsInterface(interfaceId) 
        );
    }

    

  


}
