pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./StakingPool.sol";
import "./helpers/TransferHelper.sol";

contract StakingPoolActions is Ownable, AccessControl {
  uint256 public deploymentFee;

  bytes32 public feeTakerRole = keccak256(abi.encodePacked("FEE_TAKER_ROLE"));
  bytes32 public feeSetterRole = keccak256(abi.encodePacked("FEE_SETTER_ROLE"));

  event StakingPoolDeployed(address poolId, address token0, address token1, uint256 apy1, uint256 apy2);

  constructor(uint256 _deploymentFee) {
    deploymentFee = _deploymentFee;
    _grantRole(feeTakerRole, _msgSender());
    _grantRole(feeSetterRole, _msgSender());
  }

  function deployStakingPool(
    address token0,
    address token1,
    uint256 apy1,
    uint256 apy2
  ) external payable returns (address poolId) {
    require(msg.value >= deploymentFee, "fee");
    bytes memory bytecode = abi.encodePacked(type(StakingPool).creationCode, abi.encode(_msgSender(), token0, token1, apy1, apy2));
    bytes32 salt = keccak256(abi.encodePacked(token0, token1, apy1, apy2, _msgSender(), block.timestamp));

    assembly {
      poolId := create2(0, add(bytecode, 32), mload(bytecode), salt)
      if iszero(extcodesize(poolId)) {
        revert(0, 0)
      }
    }

    emit StakingPoolDeployed(poolId, token0, token1, apy1, apy2);
  }

  function withdrawEther(address to) external {
    require(hasRole(feeTakerRole, _msgSender()));
    TransferHelpers._safeTransferEther(to, address(this).balance);
  }

  function withdrawToken(
    address token,
    address to,
    uint256 amount
  ) external {
    require(hasRole(feeTakerRole, _msgSender()));
    TransferHelpers._safeTransferERC20(token, to, amount);
  }

  function setFee(uint256 _fee) external {
    require(hasRole(feeSetterRole, _msgSender()));
    deploymentFee = _fee;
  }

  function setFeeSetter(address account) external onlyOwner {
    require(!hasRole(feeSetterRole, account));
    _grantRole(feeSetterRole, account);
  }

  function removeFeeSetter(address account) external onlyOwner {
    require(hasRole(feeSetterRole, account));
    _revokeRole(feeSetterRole, account);
  }

  function setFeeTaker(address account) external onlyOwner {
    require(!hasRole(feeTakerRole, account));
    _grantRole(feeTakerRole, account);
  }

  function removeFeeTaker(address account) external onlyOwner {
    require(hasRole(feeTakerRole, account));
    _revokeRole(feeTakerRole, account);
  }

  receive() external payable {}
}
