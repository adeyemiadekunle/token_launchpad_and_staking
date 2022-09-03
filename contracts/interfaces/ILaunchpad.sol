pragma solidity ^0.8.0;

interface ILaunchpad {
  struct TokenSaleItem {
    address token;
    uint256 tokensForSale;
    uint256 hardCap;
    uint256 softCap;
    uint256 presaleRate;
    bytes32 saleId;
    uint256 minContributionEther;
    uint256 maxContributionEther;
    uint256 saleStartTime;
    uint256 saleEndTime;
    bool interrupted;
  }

  event TokenSaleItemCreated(
    bytes32 saleId,
    address token,
    uint256 tokensForSale,
    uint256 hardCap,
    uint256 softCap,
    uint256 presaleRate,
    uint256 minContributionEther,
    uint256 maxContributionEther,
    uint256 saleStartTime,
    uint256 saleEndTime
  );

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
  ) external returns (bytes32 saleId);

  function interrupTokenSale(bytes32 saleId) external;

  function emergencyWithdrawal() external;

  function allTokenSales(uint256) external view returns (bytes32);
}
