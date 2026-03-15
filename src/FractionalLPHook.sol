// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager, SwapParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

import {ILiquidityVault} from "src/interfaces/ILiquidityVault.sol";

/**
 * @custom:security-contact security@najnomics.dev
 */
contract FractionalLPHook is BaseHook, Ownable {
    using PoolIdLibrary for PoolKey;

    error FractionalLPHook__UnknownPool();
    error FractionalLPHook__ZeroAddress();

    event PoolRegistered(PoolId indexed poolId, address indexed caller);
    event BeforeSwapObserved(PoolId indexed poolId, address indexed sender, int256 amountSpecified);
    event AfterSwapObserved(PoolId indexed poolId, address indexed sender, int256 amount0Delta, int256 amount1Delta);
    event FeeSignalHandled(PoolId indexed poolId, uint256 indexed feeValue);

    ILiquidityVault public immutable vault;

    mapping(PoolId => bool isRegisteredPool) public registeredPool;
    mapping(PoolId => uint256 beforeSwapCount) public beforeSwapCounter;
    mapping(PoolId => uint256 afterSwapCount) public afterSwapCounter;

    constructor(IPoolManager poolManager_, ILiquidityVault vault_, address owner_)
        BaseHook(poolManager_)
        Ownable(owner_)
    {
        if (address(vault_) == address(0) || owner_ == address(0)) {
            revert FractionalLPHook__ZeroAddress();
        }
        vault = vault_;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory permissions) {
        permissions = Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /*//////////////////////////////////////////////////////////////
                        USER-FACING STATE-CHANGING
    //////////////////////////////////////////////////////////////*/

    function registerPool(PoolKey calldata key) external onlyOwner {
        PoolId poolId = key.toId();
        registeredPool[poolId] = true;
        emit PoolRegistered(poolId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        if (!registeredPool[poolId]) revert FractionalLPHook__UnknownPool();

        beforeSwapCounter[poolId] += 1;
        emit BeforeSwapObserved(poolId, sender, params.amountSpecified);

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        if (!registeredPool[poolId]) revert FractionalLPHook__UnknownPool();

        afterSwapCounter[poolId] += 1;
        emit AfterSwapObserved(poolId, sender, delta.amount0(), delta.amount1());

        if (hookData.length >= 32) {
            uint256 feeSignal = abi.decode(hookData, (uint256));
            if (feeSignal > 0) {
                vault.recordAccruedFees(feeSignal);
                emit FeeSignalHandled(poolId, feeSignal);
            }
        }

        return (BaseHook.afterSwap.selector, 0);
    }
}
