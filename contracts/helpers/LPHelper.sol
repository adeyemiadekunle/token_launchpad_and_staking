pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

library LPHelper {
  using Address for address;

  function sortToken(address token1, address token2) internal view returns (address tokenA, address tokenB) {
    require(token1 != token2, "identical");
    require(token1.isContract() && token2.isContract(), "must_be_contracts");
    (tokenA, tokenB) = token1 < token2 ? (token1, token2) : (token2, token1);
  }
}
