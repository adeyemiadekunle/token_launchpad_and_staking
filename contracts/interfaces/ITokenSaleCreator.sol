// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;



interface ITokenSaleCreator {
  // Struct to hold details of a token sale
  struct TokenSaleDetails {
    address token;
    uint256 tokensForSale;
    uint256 hardCap;
    uint256 softCap;
    uint256 privatePresaleRate;
    uint256 publicPresaleRate;
    uint256 minContributionEther;
    uint256 maxContributionEther;
    uint256 saleStartTime;
    uint256 daysToLast;  // Use daysToLast instead of pre-calculated saleEndTime
    address proceedsTo;
    address admin;
    bool refundable;
    uint256 privateSaleEndTime;
  }


  struct TokenSaleItem {
    TokenSaleDetails details;
    bool interrupted;
    bool ended;
    uint256 saleEndTime; // New field to store the calculated end time
  }

  struct Contributor {
    address contributorAddress;
    uint256 amountContributed;
}

  // Event for token sale creation
  event TokenSaleItemCreated(
    bytes32 saleId,
    TokenSaleDetails details  // Use the struct for clearer representation
  );


  // Function to initiate a token sale
  function initTokenSale(
    TokenSaleDetails memory details // Pass the struct as argument
  ) external returns (bytes32 saleId);

  function interrupTokenSale(bytes32 saleId) external;

  function allTokenSales(uint256) external view returns (bytes32);

  function feePercentage() external view returns (uint256);

  function balance(bytes32 saleId, address account) external view returns (uint256);

  function amountContributed(bytes32 saleId, address account) external view returns (uint256);
}
