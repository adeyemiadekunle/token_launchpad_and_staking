pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ITokenSaleCreator.sol";
import "./helpers/TransferHelper.sol";

contract TokenSaleCreator is ReentrancyGuard, Pausable, Ownable, AccessControl, ITokenSaleCreator {
  using Address for address;
  using SafeMath for uint256;

  bytes32[] public allTokenSales;
  bytes32 public constant ADMIN_ROLE = keccak256(abi.encodePacked("ADMIN_ROLE"));
  bytes32 public pauserRole = keccak256(abi.encodePacked("PAUSER_ROLE"));
  bytes32 public withdrawerRole = keccak256(abi.encodePacked("WITHDRAWER_ROLE"));
  bytes32 public finalizerRole = keccak256(abi.encodePacked("FINALIZER_ROLE"));
  uint256 public withdrawable;
  uint256 public feePercentage;
  mapping(bytes32 => TokenSaleItem) private tokenSales;
  mapping(bytes32 => uint256) private totalEtherRaised;
  mapping(bytes32 => mapping(address => bool)) private isNotAllowedToContribute;
  mapping(bytes32 => mapping(address => uint256)) public amountContributed;
  mapping(bytes32 => mapping(address => uint256)) public balance;
  mapping(bytes32 => mapping(address => bool)) public isWhitelisted;


// Declare a modifier that can be used to check if the parameters for a token sale
  modifier whenParamsSatisfied(bytes32 saleId) {
    TokenSaleItem memory tokenSale = tokenSales[saleId];
    require(!tokenSale.interrupted, "token_sale_paused");
    require(block.timestamp >= tokenSale.saleStartTime, "token_sale_not_started_yet");
    require(!tokenSale.ended, "token_sale_has_ended");
    require(!isNotAllowedToContribute[saleId][_msgSender()], "you_are_not_allowed_to_participate_in_this_sale");
    require(totalEtherRaised[saleId] < tokenSale.hardCap, "hardcap_reached");
    _;
  }

 modifier onlyAdmin() {
  require(hasRole(ADMIN_ROLE, _msgSender()), "only_admin");
  _;
}


  /**
   * @dev Grants the pauserRole, withdrawerRole, and finalizerRole to the deployer.
   * @param _feePercentage The percentage of the token sale proceeds that will be taken as a fee.
   */
  constructor(uint256 _feePercentage) {
    // Grant the pauserRole to the deployer.
    _grantRole(pauserRole, _msgSender());

    // Grant the withdrawerRole to the deployer.
    _grantRole(withdrawerRole, _msgSender());

    // Grant the finalizerRole to the deployer.
    _grantRole(finalizerRole, _msgSender());

    // Set the fee percentage.
    feePercentage = _feePercentage;
  }


  function initTokenSale(
  address token,
  uint256 tokensForSale,
  uint256 hardCap,
  uint256 softCap,
  uint256 privatePresaleRate,
  uint256 publicPresaleRate,
  uint256 minContributionEther,
  uint256 maxContributionEther,
  uint256 saleStartTime,
  uint256 daysToLast,
  address proceedsTo,
  address admin,
  bool isRefundable,
  uint256 privateSaleEndTime // Optional end time for private sale
) external onlyAdmin whenNotPaused nonReentrant returns (bytes32 saleId) {
  require(token.isContract(), "must_be_contract_address");
  require(saleStartTime > block.timestamp && saleStartTime.sub(block.timestamp) >= 24 hours, "sale_must_begin_in_at_least_24_hours");
  require(IERC20(token).allowance(_msgSender(), address(this)) >= tokensForSale, "not_enough_allowance_given");
  TransferHelpers._safeTransferFromERC20(token, _msgSender(), address(this), tokensForSale);

  saleId = keccak256(
    abi.encodePacked(
      token,
      _msgSender(),
      block.timestamp,
      tokensForSale,
      hardCap,
      softCap,
      privatePresaleRate,
      publicPresaleRate,
      minContributionEther,
      maxContributionEther,
      saleStartTime,
      daysToLast,
      proceedsTo,
      isRefundable
    )
  );

  // Calculate end time outside the curly braces to avoid 'stack too deep' errors
  uint256 endTime = saleStartTime.add(daysToLast.mul(1 days));

  tokenSales[saleId] = TokenSaleItem(
    token,
    tokensForSale,
    hardCap,
    softCap,
    privatePresaleRate,
    publicPresaleRate,
    saleId,
    minContributionEther,
    maxContributionEther,
    saleStartTime,
    endTime,
    false, // Assuming interrupted starts as false
    proceedsTo,
    admin,
    tokensForSale, // Available tokens should be the same as total tokens for sale initially
    false, // Ended should be false by default
    isRefundable,
    privateSaleEndTime
  );

  allTokenSales.push(saleId);

  emit TokenSaleItemCreated(
    saleId,
    token,
    tokensForSale,
    hardCap,
    softCap,
    privatePresaleRate,
    publicPresaleRate,
    minContributionEther,
    maxContributionEther,
    saleStartTime,
    endTime,
    proceedsTo,
    admin
  );
}


// Function to contribute to a token sale
function contribute(bytes32 saleId) external payable whenNotPaused nonReentrant whenParamsSatisfied(saleId) {
  TokenSaleItem storage tokenSaleItem = tokenSales[saleId];
  require(
    msg.value >= tokenSaleItem.minContributionEther && msg.value <= tokenSaleItem.maxContributionEther,
    "contribution_must_be_within_min_and_max_range"
  );

 // Check for appropriate sale phase based on time
  if (block.timestamp <= tokenSaleItem.privateSaleEndTime) {
    require(isWhitelisted(msg.sender, saleId), "not_whitelisted_for_private_sale");
  }

  uint256 presaleRate;
  if (block.timestamp <= tokenSaleItem.privateSaleEndTime) {
    presaleRate = tokenSaleItem.privatePresaleRate;
  } else {
    presaleRate = tokenSaleItem.publicPresaleRate;
  }
  uint256 val = presaleRate.mul(msg.value).div(1 ether);

  require(tokenSaleItem.availableTokens >= val, "tokens_available_for_sale_is_less");
  balance[saleId][_msgSender()] = balance[saleId][_msgSender()].add(val);
  amountContributed[saleId][_msgSender()] = amountContributed[saleId][_msgSender()].add(msg.value);
  totalEtherRaised[saleId] = totalEtherRaised[saleId].add(msg.value);
  tokenSaleItem.availableTokens = tokenSaleItem.availableTokens.sub(val);
}



// Function to withdraw tokens from a sale that has ended or reached its end time.
  function normalWithdrawal(bytes32 saleId) external whenNotPaused nonReentrant {
    TokenSaleItem storage tokenSaleItem = tokenSales[saleId];
    require(tokenSaleItem.ended || block.timestamp >= tokenSaleItem.saleEndTime, "sale_has_not_ended");
    TransferHelpers._safeTransferERC20(tokenSaleItem.token, _msgSender(), balance[saleId][_msgSender()]);
    delete balance[saleId][_msgSender()];
  }

// Function to withdraw funds in case of an emergency
  function emergencyWithdrawal(bytes32 saleId) external nonReentrant {
    TokenSaleItem storage tokenSaleItem = tokenSales[saleId];
    require(!tokenSaleItem.ended, "sale_has_already_ended");
    TransferHelpers._safeTransferEther(_msgSender(), amountContributed[saleId][_msgSender()]);
    tokenSaleItem.availableTokens = tokenSaleItem.availableTokens.add(balance[saleId][_msgSender()]);
    totalEtherRaised[saleId] = totalEtherRaised[saleId].sub(amountContributed[saleId][_msgSender()]);
    delete balance[saleId][_msgSender()];
    delete amountContributed[saleId][_msgSender()];
  }


// Function to pause the Sales
  function interrupTokenSale(bytes32 saleId) external whenNotPaused onlyOwner {
    TokenSaleItem storage tokenSale = tokenSales[saleId];
    require(!tokenSale.ended, "token_sale_has_ended");
    tokenSale.interrupted = true;
  }

// Function to resume the Sales
  function uninterrupTokenSale(bytes32 saleId) external whenNotPaused onlyOwner {
    TokenSaleItem storage tokenSale = tokenSales[saleId];
    tokenSale.interrupted = false;
  }

// Function to finalize the Token sales
 function finalizeTokenSale(bytes32 saleId) external whenNotPaused {
  if (!tokenSales[saleId].ended && totalEtherRaised[saleId] < tokenSales[saleId].softCap && tokenSales[saleId].refundable) {
    // initiate refund process
    initiateRefunds(saleId);
  } else {
    TokenSaleItem storage tokenSale = tokenSales[saleId];
    require(hasRole(finalizerRole, _msgSender()) || tokenSale.admin == _msgSender(), "only_finalizer_or_admin");
    require(!tokenSale.ended, "sale_has_ended");
    uint256 platformFees = (totalEtherRaised[saleId] * feePercentage).div(100);
    TransferHelpers._safeTransferEther(tokenSale.proceedsTo, totalEtherRaised[saleId] - platformFees);
    withdrawable = withdrawable.add(platformFees);

    if (tokenSale.availableTokens > 0) {
      // Optional: Implement custom logic for handling unsold tokens
      TransferHelpers._safeTransferERC20(tokenSale.token, tokenSale.proceedsTo, tokenSale.availableTokens);
    }

    tokenSale.ended = true;
  }
}

// Bar from participatinn
  function barFromParticiption(bytes32 saleId, address account) external {
    TokenSaleItem memory tokenSale = tokenSales[saleId];
    require(tokenSale.admin == _msgSender(), "only_admin");
    require(!tokenSale.ended, "sale_has_ended");
    require(!isNotAllowedToContribute[saleId][account], "already_barred");
    isNotAllowedToContribute[saleId][account] = true;
  }

  function rescindBar(bytes32 saleId, address account) external {
    TokenSaleItem memory tokenSale = tokenSales[saleId];
    require(tokenSale.admin == _msgSender(), "only_admin");
    require(!tokenSale.ended, "sale_has_ended");
    require(isNotAllowedToContribute[saleId][account], "not_barred");
    isNotAllowedToContribute[saleId][account] = false;
  }

// Function to initial refund
  function initiateRefunds(bytes32 saleId) private {
  for (address contributor in getContributors(saleId)) {
    TransferHelpers._safeTransferEther(contributor, amountContributed[saleId][contributor]);
  }
}

function cancelSale(bytes32 saleId) external onlyOwner {
  require(!tokenSale.ended, "sale_already_ended");
  tokenSale.ended = true;
  initiateRefunds(saleId); // initiate refunds if applicable
}

function getContributors(bytes32 saleId) public view returns (address[] memory) {
  uint256 contributorCount = 0;
  for (address contributor in allTokenSales) {
    if (amountContributed[saleId][contributor] > 0) {
      contributorCount++;
    }
  }

  address[] memory contributors = new address[](contributorCount);
  uint256 index = 0;
  for (address contributor in allTokenSales) {
    if (amountContributed[saleId][contributor] > 0) {
      contributors[index] = contributor;
      index++;
    }
  }
  return contributors;
}

function addToWhitelist(bytes32 saleId, address[] memory contributors) external {
  require(hasRole(adminRole, _msgSender()), "only_admin_can_whitelist");
  for (address contributor in contributors) {
    isWhitelisted[saleId][contributor] = true;
  }
}

function removeFromWhitelist(bytes32 saleId, address contributor) external {
  require(hasRole(adminRole, _msgSender()), "only_admin_can_remove_whitelist");
  isWhitelisted[saleId][contributor] = false;
}


  function pause() external whenNotPaused {
    require(hasRole(pauserRole, _msgSender()), "must_have_pauser_role");
    _pause();
  }

  function unpause() external whenPaused {
    require(hasRole(pauserRole, _msgSender()), "must_have_pauser_role");
    _unpause();
  }

  function getTotalEtherRaisedForSale(bytes32 saleId) external view returns (uint256) {
    return totalEtherRaised[saleId];
  }

  function getExpectedEtherRaiseForSale(bytes32 saleId) external view returns (uint256) {
    TokenSaleItem memory tokenSaleItem = tokenSales[saleId];
    return tokenSaleItem.hardCap;
  }

  function getSoftCap(bytes32 saleId) external view returns (uint256) {
    TokenSaleItem memory tokenSaleItem = tokenSales[saleId];
    return tokenSaleItem.softCap;
  }

  function withdrawProfit(address to) external {
    require(hasRole(withdrawerRole, _msgSender()), "only_withdrawer");
    TransferHelpers._safeTransferEther(to, withdrawable);
    withdrawable = 0;
  }

  receive() external payable {
    withdrawable = withdrawable.add(msg.value);
  }
}
