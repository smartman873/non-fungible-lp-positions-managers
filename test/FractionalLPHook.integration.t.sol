// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager, SwapParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";

import {EasyPosm} from "test/utils/libraries/EasyPosm.sol";
import {BaseTest} from "test/utils/BaseTest.sol";

import {FractionalLPHook} from "src/FractionalLPHook.sol";
import {LiquidityVault} from "src/LiquidityVault.sol";
import {ILiquidityVault} from "src/interfaces/ILiquidityVault.sol";

contract FractionalLPHookIntegrationTest is BaseTest {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    address internal owner = makeAddr("owner");
    address internal userA = makeAddr("userA");
    address internal userB = makeAddr("userB");

    Currency internal currency0;
    Currency internal currency1;
    PoolKey internal poolKey;
    PoolId internal poolId;

    FractionalLPHook internal hook;
    LiquidityVault internal vault;

    function setUp() external {
        deployArtifactsAndLabel();

        (currency0, currency1) = deployCurrencyPair();

        vault = new LiquidityVault(
            owner,
            IERC20(Currency.unwrap(currency0)),
            IERC20(Currency.unwrap(currency1)),
            "Fractional LP Share",
            "FLPS",
            true
        );

        address flags = address(uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG) ^ (0x4444 << 144));
        bytes memory constructorArgs = abi.encode(poolManager, vault, owner);
        deployCodeTo("FractionalLPHook.sol:FractionalLPHook", constructorArgs, flags);
        hook = FractionalLPHook(flags);

        vm.prank(owner);
        vault.setHook(address(hook));

        poolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = poolKey.toId();

        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        vm.prank(owner);
        hook.registerPool(poolKey);

        int24 tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );

        MockERC20(Currency.unwrap(currency0)).mint(userA, 10_000e18);
        MockERC20(Currency.unwrap(currency1)).mint(userA, 10_000e18);
        MockERC20(Currency.unwrap(currency0)).mint(userB, 10_000e18);
        MockERC20(Currency.unwrap(currency1)).mint(userB, 10_000e18);

        vm.startPrank(userA);
        MockERC20(Currency.unwrap(currency0)).approve(address(vault), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(userB);
        MockERC20(Currency.unwrap(currency0)).approve(address(vault), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function test_DeployWithoutPermissionBitsReverts() external {
        vm.expectRevert();
        new FractionalLPHook(poolManager, ILiquidityVault(address(vault)), owner);
    }

    function test_ConstructorRevertsOnZeroVaultWhenPermissionAddressIsValid() external {
        address flags = address(uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG) ^ (0x4545 << 144));
        bytes memory constructorArgs = abi.encode(poolManager, ILiquidityVault(address(0)), owner);

        vm.expectRevert(FractionalLPHook.FractionalLPHook__ZeroAddress.selector);
        deployCodeTo("FractionalLPHook.sol:FractionalLPHook", constructorArgs, flags);
    }

    function test_GetHookPermissionsAreSet() external view {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertFalse(permissions.beforeInitialize);
    }

    function test_BeforeSwapRevertsForUnregisteredPool() external {
        PoolKey memory unknownPoolKey = _unregisteredPoolKey();
        SwapParams memory params = _dummySwapParams();

        vm.prank(address(poolManager));
        vm.expectRevert(FractionalLPHook.FractionalLPHook__UnknownPool.selector);
        hook.beforeSwap(address(this), unknownPoolKey, params, bytes(""));
    }

    function test_AfterSwapRevertsForUnregisteredPool() external {
        PoolKey memory unknownPoolKey = _unregisteredPoolKey();
        SwapParams memory params = _dummySwapParams();

        vm.prank(address(poolManager));
        vm.expectRevert(FractionalLPHook.FractionalLPHook__UnknownPool.selector);
        hook.afterSwap(address(this), unknownPoolKey, params, BalanceDelta.wrap(0), bytes(""));
    }

    function test_AfterSwapSkipsAccrualForShortHookData() external {
        vm.prank(address(poolManager));
        hook.afterSwap(address(this), poolKey, _dummySwapParams(), BalanceDelta.wrap(0), bytes("abcd"));

        assertEq(hook.afterSwapCounter(poolId), 1);
        assertEq(vault.snapshot().accumulatedFees, 0);
    }

    function test_AfterSwapSkipsAccrualForZeroFeeSignal() external {
        vm.prank(address(poolManager));
        hook.afterSwap(address(this), poolKey, _dummySwapParams(), BalanceDelta.wrap(0), abi.encode(uint256(0)));

        assertEq(hook.afterSwapCounter(poolId), 1);
        assertEq(vault.snapshot().accumulatedFees, 0);
    }

    function test_EndToEndFractionalLifecycle() external {
        vm.prank(userA);
        uint256 sharesA = vault.deposit(1_000e18, 1_000e18, userA);
        assertEq(sharesA, 2_000e18);

        vm.prank(userB);
        uint256 sharesB = vault.deposit(500e18, 500e18, userB);
        assertEq(sharesB, 1_000e18);

        MockERC20(Currency.unwrap(currency0)).mint(address(vault), 25e18);
        MockERC20(Currency.unwrap(currency1)).mint(address(vault), 25e18);

        bytes memory hookData = abi.encode(50e18);
        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: 1e18,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: hookData,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        assertEq(int256(swapDelta.amount0()), -1e18);

        assertEq(hook.beforeSwapCounter(poolId), 1);
        assertEq(hook.afterSwapCounter(poolId), 1);

        uint256 totalBeforeRedeem = vault.totalVaultValue();

        vm.prank(userA);
        (uint256 amount0Out, uint256 amount1Out) = vault.redeem(sharesA, userA);

        assertGt(amount0Out + amount1Out, 2_000e18);
        assertLt(vault.totalVaultValue(), totalBeforeRedeem);
    }

    function _dummySwapParams() internal pure returns (SwapParams memory params) {
        params = SwapParams({zeroForOne: true, amountSpecified: -1e18, sqrtPriceLimitX96: 1});
    }

    function _unregisteredPoolKey() internal view returns (PoolKey memory unknownPoolKey) {
        unknownPoolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 500,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
    }
}
