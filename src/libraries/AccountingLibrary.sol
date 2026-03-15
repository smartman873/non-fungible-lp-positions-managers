// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library AccountingLibrary {
    uint256 internal constant Q96 = 2 ** 96;

    error AccountingLibrary__ZeroAmount();
    error AccountingLibrary__ZeroShares();
    error AccountingLibrary__InvalidVaultValue();

    struct VaultState {
        uint256 totalShares;
        uint256 totalLiquidity;
        uint256 accumulatedFees;
        uint256 sharePriceX96;
        uint256 lastUpdateBlock;
    }

    function totalVaultValue(VaultState memory state) internal pure returns (uint256) {
        return state.totalLiquidity + state.accumulatedFees;
    }

    function computeSharesForDeposit(uint256 depositValue, uint256 totalShares, uint256 totalValueBefore)
        internal
        pure
        returns (uint256 sharesMinted)
    {
        if (depositValue == 0) revert AccountingLibrary__ZeroAmount();

        if (totalShares == 0 || totalValueBefore == 0) {
            return depositValue;
        }

        sharesMinted = (depositValue * totalShares) / totalValueBefore;
        if (sharesMinted == 0) {
            sharesMinted = 1;
        }
    }

    function computeAssetsForRedeem(uint256 sharesBurned, uint256 totalShares, uint256 totalValueBefore)
        internal
        pure
        returns (uint256 withdrawValue)
    {
        if (sharesBurned == 0) revert AccountingLibrary__ZeroAmount();
        if (totalShares == 0) revert AccountingLibrary__ZeroShares();
        if (totalValueBefore == 0) revert AccountingLibrary__InvalidVaultValue();

        withdrawValue = (sharesBurned * totalValueBefore) / totalShares;
    }

    function computeSharePriceX96(uint256 totalShares, uint256 totalVaultValue_) internal pure returns (uint256) {
        if (totalShares == 0 || totalVaultValue_ == 0) {
            return Q96;
        }
        return (totalVaultValue_ * Q96) / totalShares;
    }
}
