pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILaunchpad.sol";
import "./helpers/TransferHelper.sol";

contract Launchpad is ReentrancyGuard, Pausable, Ownable, AccessControl, ILaunchpad {
  using Address for address;
  using SafeMath for uint256;

  bytes32[] public allTokenSales;
  bytes32 public pauserRole = keccak256(abi.encodePacked("PAUSER_ROLE"));
  bytes32 public withdrawerRole = keccak256(abi.encodePacked("WITHDRAWER_ROLE"));
  uint256 public withdrawable;

  mapping(bytes32 => TokenSaleItem) private tokenSales;

  constructor() {
    _grantRole(pauserRole, _msgSender());
    _grantRole(withdrawerRole, _msgSender());
  }

  function initTokenSale(
    address token,
    uint256 tokensForSale,
    uint256 hardCap,
    uint256 softCap,
    uint256 presaleRate,
    uint256 minContributionEther,
    uint256 maxContributionEther,
    uint256 saleStartTime,
    uint256 daysToLast
  ) external whenNotPaused nonReentrant returns (bytes32 saleId) {
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
        presaleRate,
        minContributionEther,
        maxContributionEther,
        saleStartTime,
        daysToLast
      )
    );
    tokenSales[saleId] = TokenSaleItem(
      token,
      tokensForSale,
      hardCap,
      softCap,
      presaleRate,
      saleId,
      minContributionEther,
      maxContributionEther,
      saleStartTime,
      saleStartTime.add(daysToLast * 1 days),
      false
    );
    allTokenSales.push(saleId);
    emit TokenSaleItemCreated(
      saleId,
      token,
      tokensForSale,
      hardCap,
      softCap,
      presaleRate,
      minContributionEther,
      maxContributionEther,
      saleStartTime,
      saleStartTime.add(daysToLast * 1 days)
    );
  }
}
