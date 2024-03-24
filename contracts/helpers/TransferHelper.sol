// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

library TransferHelpers {
    function _safeTransferEther(address to, uint256 amount)
        internal
        returns (bool success)
    {
        (success, ) = to.call{value: amount}(new bytes(0));
        if (!success) {
            revert("failed to transfer ether");
        }
        return success;
    }

    function _safeTransferERC20(
        address token,
        address to,
        uint256 amount
    ) internal returns (bool success) {
        (success, ) = token.call(
            abi.encodeWithSelector(
                bytes4(keccak256("transfer(address,uint256)")),
                to,
                amount
            )
        );
        if (!success) revert("low_level_contract_call_failed");
        return true;
    }

    function _safeTransferFromERC20(
        address token,
        address spender,
        address recipient,
        uint256 amount
    ) internal returns (bool success) {
        (success, ) = token.call(
            abi.encodeWithSelector(
                bytes4(keccak256("transferFrom(address,address,uint256)")),
                spender,
                recipient,
                amount
            )
        );
        if (!success) revert("low_level_contract_call_failed");
        return true;
    }
}
