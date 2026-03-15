// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {AccountingLibrary} from "src/libraries/AccountingLibrary.sol";

contract AccountingLibraryTest is Test {
    using AccountingLibrary for AccountingLibrary.VaultState;

    function callComputeAssetsForRedeem(uint256 sharesBurned, uint256 totalShares, uint256 totalValueBefore)
        external
        pure
        returns (uint256)
    {
        return AccountingLibrary.computeAssetsForRedeem(sharesBurned, totalShares, totalValueBefore);
    }

    function test_ComputeSharesForFirstDeposit() external pure {
        uint256 minted = AccountingLibrary.computeSharesForDeposit(1_000e18, 0, 0);
        assertEq(minted, 1_000e18);
    }

    function test_ComputeSharesForExistingVault() external pure {
        uint256 minted = AccountingLibrary.computeSharesForDeposit(100e18, 1_000e18, 2_000e18);
        assertEq(minted, 50e18);
    }

    function test_ComputeAssetsForRedeem() external pure {
        uint256 redeemed = AccountingLibrary.computeAssetsForRedeem(10e18, 100e18, 500e18);
        assertEq(redeemed, 50e18);
    }

    function test_ComputeSharePriceX96() external pure {
        uint256 price = AccountingLibrary.computeSharePriceX96(1_000e18, 1_100e18);
        assertEq(price, (1_100e18 * uint256(2 ** 96)) / 1_000e18);
    }

    function test_RevertOnZeroRedeemShares() external {
        vm.expectRevert(AccountingLibrary.AccountingLibrary__ZeroAmount.selector);
        this.callComputeAssetsForRedeem(0, 10, 10);
    }

    function test_RevertOnZeroTotalShares() external {
        vm.expectRevert(AccountingLibrary.AccountingLibrary__ZeroShares.selector);
        this.callComputeAssetsForRedeem(1, 0, 10);
    }
}
