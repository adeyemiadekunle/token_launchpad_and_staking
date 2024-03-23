pragma solidity ^0.8.0;



interface ITokenSaleCreator {
  struct TokenSaleItem {
    address token;
    uint256 tokensForSale;
    uint256 hardCap;
    uint256 softCap;
    uint256 privatePresaleRate;
    uint256 publicPresaleRate;
    bytes32 saleId;
    uint256 minContributionEther;
    uint256 maxContributionEther;
    uint256 saleStartTime;
    uint256 saleEndTime;
    uint256 privateSaledEndTime;
    bool interrupted;
    address proceedsTo;
    address admin;
    uint256 availableTokens;
    bool ended;
    bool refundable;
  }

  event TokenSaleItemCreated(
    bytes32 saleId,
    address token,
    uint256 tokensForSale,
    uint256 hardCap,
    uint256 softCap,
    uint256 privatePresaleRate;
    uint256 publicPresaleRate;
    uint256 minContributionEther,
    uint256 maxContributionEther,
    uint256 saleStartTime,
    uint256 saleEndTime,
    address proceedsTo,
    address admin,
    bool refundable
  );

  function initTokenSale(
    address token,
    uint256 tokensForSale,
    uint256 hardCap,
    uint256 softCap,
    uint256 privatePresaleRate;
    uint256 publicPresaleRate;
    uint256 minContributionEther,
    uint256 maxContributionEther,
    uint256 saleStartTime,
    uint256 privateSaledEndTime;
    uint256 daysToLast,
    address proceedsTo,
    address admin,
    bool refundable
  ) external returns (bytes32 saleId);

  function interrupTokenSale(bytes32 saleId) external;

  function allTokenSales(uint256) external view returns (bytes32);

  function feePercentage() external view returns (uint256);

  function balance(bytes32 saleId, address account) external view returns (uint256);

  function amountContributed(bytes32 saleId, address account) external view returns (uint256);
}
