// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {AccountingLibrary} from "src/libraries/AccountingLibrary.sol";
import {FractionalToken} from "src/FractionalToken.sol";
import {PositionNFT} from "src/PositionNFT.sol";

/**
 * @custom:security-contact security@najnomics.dev
 */
contract LiquidityVault is Ownable, ReentrancyGuard {
    using AccountingLibrary for AccountingLibrary.VaultState;
    using SafeERC20 for IERC20;

    error LiquidityVault__ZeroAddress();
    error LiquidityVault__ZeroDeposit();
    error LiquidityVault__ZeroShares();
    error LiquidityVault__InvalidShareAmount();
    error LiquidityVault__UnauthorizedHook();
    error LiquidityVault__HookAlreadySet();
    error LiquidityVault__LossExceedsLiquidity();

    event Deposited(
        address indexed caller,
        address indexed receiver,
        uint256 amount0,
        uint256 amount1,
        uint256 depositValue,
        uint256 sharesMinted
    );
    event Redeemed(
        address indexed caller,
        address indexed receiver,
        uint256 sharesBurned,
        uint256 amount0,
        uint256 amount1,
        uint256 withdrawValue
    );
    event FeesAccrued(address indexed caller, uint256 feeValue, uint256 newSharePriceX96);
    event LossRecorded(address indexed caller, uint256 lossValue, uint256 newSharePriceX96);
    event HookSet(address indexed oldHook, address indexed newHook);
    event LiquiditySynced(address indexed caller, uint256 oldLiquidity, uint256 newLiquidity, uint256 newSharePriceX96);

    struct VaultSnapshot {
        uint256 totalShares;
        uint256 totalLiquidity;
        uint256 accumulatedFees;
        uint256 sharePriceX96;
        uint256 lastUpdateBlock;
        uint256 totalVaultValue;
    }

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    FractionalToken public immutable shareToken;
    PositionNFT public immutable positionNFT;

    address public hook;
    AccountingLibrary.VaultState private vaultState;

    constructor(
        address owner_,
        IERC20 token0_,
        IERC20 token1_,
        string memory shareName_,
        string memory shareSymbol_,
        bool deployPositionNft
    ) Ownable(owner_) {
        if (owner_ == address(0)) revert LiquidityVault__ZeroAddress();
        if (address(token0_) == address(0) || address(token1_) == address(0)) revert LiquidityVault__ZeroAddress();
        if (address(token0_) == address(token1_)) revert LiquidityVault__ZeroAddress();

        token0 = token0_;
        token1 = token1_;
        shareToken = new FractionalToken(shareName_, shareSymbol_, address(this));

        if (deployPositionNft) {
            positionNFT = new PositionNFT("Fractional LP Vault", "FLPV", owner_);
        }

        vaultState.sharePriceX96 = AccountingLibrary.Q96;
        vaultState.lastUpdateBlock = block.number;
    }

    modifier onlyHook() {
        if (msg.sender != hook) revert LiquidityVault__UnauthorizedHook();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        USER-FACING STATE-CHANGING
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 amount0, uint256 amount1, address receiver)
        external
        nonReentrant
        returns (uint256 sharesMinted)
    {
        if (receiver == address(0)) revert LiquidityVault__ZeroAddress();
        uint256 depositValue = amount0 + amount1;
        if (depositValue == 0) revert LiquidityVault__ZeroDeposit();

        uint256 totalValueBefore = totalVaultValue();

        if (amount0 > 0) token0.safeTransferFrom(msg.sender, address(this), amount0);
        if (amount1 > 0) token1.safeTransferFrom(msg.sender, address(this), amount1);

        sharesMinted = AccountingLibrary.computeSharesForDeposit(depositValue, vaultState.totalShares, totalValueBefore);

        vaultState.totalShares += sharesMinted;
        vaultState.totalLiquidity += depositValue;
        _refreshSharePrice();

        shareToken.mint(receiver, sharesMinted);

        emit Deposited(msg.sender, receiver, amount0, amount1, depositValue, sharesMinted);
    }

    function redeem(uint256 sharesBurned, address receiver)
        external
        nonReentrant
        returns (uint256 amount0Out, uint256 amount1Out)
    {
        if (receiver == address(0)) revert LiquidityVault__ZeroAddress();
        if (sharesBurned == 0) revert LiquidityVault__ZeroShares();
        if (sharesBurned > shareToken.balanceOf(msg.sender)) revert LiquidityVault__InvalidShareAmount();

        uint256 totalValueBefore = totalVaultValue();
        uint256 withdrawValue =
            AccountingLibrary.computeAssetsForRedeem(sharesBurned, vaultState.totalShares, totalValueBefore);

        uint256 available0 = token0.balanceOf(address(this));
        uint256 available1 = token1.balanceOf(address(this));
        uint256 totalAvailable = available0 + available1;
        if (withdrawValue > totalAvailable) {
            withdrawValue = totalAvailable;
        }

        shareToken.burnFrom(msg.sender, sharesBurned);
        vaultState.totalShares -= sharesBurned;

        uint256 fromLiquidity = withdrawValue > vaultState.totalLiquidity ? vaultState.totalLiquidity : withdrawValue;
        vaultState.totalLiquidity -= fromLiquidity;
        vaultState.accumulatedFees -= (withdrawValue - fromLiquidity);

        if (totalAvailable > 0 && withdrawValue > 0) {
            amount0Out = (withdrawValue * available0) / totalAvailable;
            amount1Out = withdrawValue - amount0Out;
        }

        if (amount0Out > 0) token0.safeTransfer(receiver, amount0Out);
        if (amount1Out > 0) token1.safeTransfer(receiver, amount1Out);

        _refreshSharePrice();

        emit Redeemed(msg.sender, receiver, sharesBurned, amount0Out, amount1Out, withdrawValue);
    }

    function setHook(address hook_) external onlyOwner {
        if (hook_ == address(0)) revert LiquidityVault__ZeroAddress();
        if (hook != address(0)) revert LiquidityVault__HookAlreadySet();

        address oldHook = hook;
        hook = hook_;
        emit HookSet(oldHook, hook_);
    }

    function donateFees(uint256 amount0, uint256 amount1) external nonReentrant {
        uint256 feeValue = amount0 + amount1;
        if (feeValue == 0) revert LiquidityVault__ZeroDeposit();

        if (amount0 > 0) token0.safeTransferFrom(msg.sender, address(this), amount0);
        if (amount1 > 0) token1.safeTransferFrom(msg.sender, address(this), amount1);

        vaultState.accumulatedFees += feeValue;
        _refreshSharePrice();

        emit FeesAccrued(msg.sender, feeValue, vaultState.sharePriceX96);
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK STATE-CHANGING
    //////////////////////////////////////////////////////////////*/

    function recordAccruedFees(uint256 feeValue) external onlyHook {
        if (feeValue == 0) revert LiquidityVault__ZeroDeposit();

        vaultState.accumulatedFees += feeValue;
        _refreshSharePrice();

        emit FeesAccrued(msg.sender, feeValue, vaultState.sharePriceX96);
    }

    function syncLiquidity(uint256 newLiquidity) external onlyHook {
        uint256 oldLiquidity = vaultState.totalLiquidity;
        vaultState.totalLiquidity = newLiquidity;
        _refreshSharePrice();
        emit LiquiditySynced(msg.sender, oldLiquidity, newLiquidity, vaultState.sharePriceX96);
    }

    function recordLoss(uint256 lossValue) external onlyOwner {
        if (lossValue == 0) revert LiquidityVault__ZeroDeposit();
        if (lossValue > vaultState.totalLiquidity) revert LiquidityVault__LossExceedsLiquidity();

        vaultState.totalLiquidity -= lossValue;
        _refreshSharePrice();

        emit LossRecorded(msg.sender, lossValue, vaultState.sharePriceX96);
    }

    /*//////////////////////////////////////////////////////////////
                             READ-ONLY
    //////////////////////////////////////////////////////////////*/

    function totalVaultValue() public view returns (uint256) {
        return vaultState.totalVaultValue();
    }

    function sharePriceX96() external view returns (uint256) {
        return vaultState.sharePriceX96;
    }

    function snapshot() external view returns (VaultSnapshot memory state) {
        state = VaultSnapshot({
            totalShares: vaultState.totalShares,
            totalLiquidity: vaultState.totalLiquidity,
            accumulatedFees: vaultState.accumulatedFees,
            sharePriceX96: vaultState.sharePriceX96,
            lastUpdateBlock: vaultState.lastUpdateBlock,
            totalVaultValue: totalVaultValue()
        });
    }

    function previewDeposit(uint256 amount0, uint256 amount1) external view returns (uint256 sharesMinted) {
        uint256 depositValue = amount0 + amount1;
        sharesMinted =
            AccountingLibrary.computeSharesForDeposit(depositValue, vaultState.totalShares, totalVaultValue());
    }

    function previewRedeem(uint256 sharesBurned) external view returns (uint256 withdrawValue) {
        withdrawValue =
            AccountingLibrary.computeAssetsForRedeem(sharesBurned, vaultState.totalShares, totalVaultValue());
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _refreshSharePrice() internal {
        uint256 vaultValue = totalVaultValue();
        vaultState.sharePriceX96 = AccountingLibrary.computeSharePriceX96(vaultState.totalShares, vaultValue);
        vaultState.lastUpdateBlock = block.number;
    }
}
