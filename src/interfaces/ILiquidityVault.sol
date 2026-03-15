// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ILiquidityVault {
    function recordAccruedFees(uint256 feeValue) external;
}
