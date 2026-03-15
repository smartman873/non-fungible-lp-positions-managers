// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import {Deployers} from "test/utils/Deployers.sol";
import {EasyPosm} from "test/utils/libraries/EasyPosm.sol";

import {MockToken} from "src/mocks/MockToken.sol";
import {LiquidityVault} from "src/LiquidityVault.sol";
import {FractionalLPHook} from "src/FractionalLPHook.sol";
import {ILiquidityVault} from "src/interfaces/ILiquidityVault.sol";

contract DemoFractionalLifecycleScript is Script, Deployers {
    using EasyPosm for IPositionManager;

    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    // Anvil default keys. Local demo only.
    uint256 internal constant ANVIL_PK_0 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 internal constant ANVIL_PK_1 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 internal constant ANVIL_PK_2 = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    struct DemoContext {
        address deployer;
        address userA;
        address userB;
        MockToken token0;
        MockToken token1;
        LiquidityVault vault;
        FractionalLPHook hook;
        PoolKey poolKey;
    }

    function _etch(address target, bytes memory bytecode) internal override {
        if (block.chainid == 31337) {
            vm.rpc("anvil_setCode", string.concat('["', vm.toString(target), '",', '"', vm.toString(bytecode), '"]'));
        } else {
            revert("DemoFractionalLifecycleScript: local only");
        }
    }

    function run() external {
        require(block.chainid == 31337, "DemoFractionalLifecycleScript: local anvil only");

        DemoContext memory ctx = _deployDemoContext();
        (uint256 sharesA, uint256 sharesB) = _executeDeposits(ctx);
        BalanceDelta swapDelta = _executeSwapAndAccrue(ctx);
        _executeRedeemAndReport(ctx, sharesA, sharesB, swapDelta);
    }

    function _deployDemoContext() internal returns (DemoContext memory ctx) {
        ctx.deployer = vm.addr(ANVIL_PK_0);
        ctx.userA = vm.addr(ANVIL_PK_1);
        ctx.userB = vm.addr(ANVIL_PK_2);

        // Permit2 is canonical and needs bytecode etched before broadcast transactions.
        deployPermit2();

        vm.startBroadcast(ANVIL_PK_0);
        deployPoolManager();
        deployPositionManager();
        deployRouter();

        (ctx.token0, ctx.token1) = _deployAndFundTokens(ctx.deployer, ctx.userA, ctx.userB);
        _approveProtocolSpenders(ctx.token0, ctx.token1);

        ctx.vault = new LiquidityVault(
            ctx.deployer, IERC20(address(ctx.token0)), IERC20(address(ctx.token1)), "Fractional LP Share", "FLPS", true
        );
        ctx.hook = _deployHook(ctx.deployer, ctx.vault);
        ctx.vault.setHook(address(ctx.hook));

        ctx.poolKey = PoolKey({
            currency0: Currency.wrap(address(ctx.token0)),
            currency1: Currency.wrap(address(ctx.token1)),
            fee: 3_000,
            tickSpacing: 60,
            hooks: IHooks(ctx.hook)
        });

        poolManager.initialize(ctx.poolKey, SQRT_PRICE_1_1);
        ctx.hook.registerPool(ctx.poolKey);

        _seedInitialLiquidity(ctx.poolKey, ctx.deployer);

        vm.stopBroadcast();
    }

    function _deployAndFundTokens(address deployer, address userA, address userB)
        internal
        returns (MockToken token0, MockToken token1)
    {
        token0 = new MockToken("Mock USDC", "mUSDC");
        token1 = new MockToken("Mock WETH", "mWETH");

        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        token0.mint(userA, 2_000_000e18);
        token1.mint(userA, 2_000_000e18);
        token0.mint(userB, 2_000_000e18);
        token1.mint(userB, 2_000_000e18);
        token0.mint(deployer, 2_000_000e18);
        token1.mint(deployer, 2_000_000e18);
    }

    function _approveProtocolSpenders(MockToken token0, MockToken token1) internal {
        token0.approve(address(permit2), type(uint256).max);
        token1.approve(address(permit2), type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);

        permit2.approve(address(token0), address(positionManager), type(uint160).max, type(uint48).max);
        permit2.approve(address(token1), address(positionManager), type(uint160).max, type(uint48).max);
        permit2.approve(address(token0), address(poolManager), type(uint160).max, type(uint48).max);
        permit2.approve(address(token1), address(poolManager), type(uint160).max, type(uint48).max);
    }

    function _deployHook(address owner, LiquidityVault vault) internal returns (FractionalLPHook hook) {
        bytes memory constructorArgs = abi.encode(poolManager, ILiquidityVault(address(vault)), owner);
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);

        (address expectedHookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_FACTORY, flags, type(FractionalLPHook).creationCode, constructorArgs);

        hook = new FractionalLPHook{salt: salt}(poolManager, ILiquidityVault(address(vault)), owner);
        require(address(hook) == expectedHookAddress, "DemoFractionalLifecycleScript: hook mismatch");
    }

    function _seedInitialLiquidity(PoolKey memory poolKey, address deployer) internal {
        int24 tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);
        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
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
            deployer,
            block.timestamp,
            bytes("")
        );
    }

    function _executeDeposits(DemoContext memory ctx) internal returns (uint256 sharesA, uint256 sharesB) {
        vm.startBroadcast(ANVIL_PK_1);
        ctx.token0.approve(address(ctx.vault), type(uint256).max);
        ctx.token1.approve(address(ctx.vault), type(uint256).max);
        sharesA = ctx.vault.deposit(1_000e18, 1_000e18, ctx.userA);
        vm.stopBroadcast();

        vm.startBroadcast(ANVIL_PK_2);
        ctx.token0.approve(address(ctx.vault), type(uint256).max);
        ctx.token1.approve(address(ctx.vault), type(uint256).max);
        sharesB = ctx.vault.deposit(500e18, 500e18, ctx.userB);
        vm.stopBroadcast();
    }

    function _executeSwapAndAccrue(DemoContext memory ctx) internal returns (BalanceDelta swapDelta) {
        vm.startBroadcast(ANVIL_PK_0);
        ctx.token0.mint(address(ctx.vault), 25e18);
        ctx.token1.mint(address(ctx.vault), 25e18);

        swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: 1e18,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: ctx.poolKey,
            hookData: abi.encode(50e18),
            receiver: ctx.deployer,
            deadline: block.timestamp + 30
        });
        vm.stopBroadcast();
    }

    function _executeRedeemAndReport(DemoContext memory ctx, uint256 sharesA, uint256 sharesB, BalanceDelta swapDelta)
        internal
    {
        uint256 valueBeforeRedeem = ctx.vault.totalVaultValue();

        vm.startBroadcast(ANVIL_PK_1);
        (uint256 amount0Out, uint256 amount1Out) = ctx.vault.redeem(sharesA, ctx.userA);
        vm.stopBroadcast();

        uint256 valueAfterRedeem = ctx.vault.totalVaultValue();

        console2.log("deployer", ctx.deployer);
        console2.log("userA", ctx.userA);
        console2.log("userB", ctx.userB);
        console2.log("vault", address(ctx.vault));
        console2.log("hook", address(ctx.hook));
        console2.log("sharesA", sharesA);
        console2.log("sharesB", sharesB);
        console2.log("swapAmount0Delta", swapDelta.amount0());
        console2.log("swapAmount1Delta", swapDelta.amount1());
        console2.log("valueBeforeRedeem", valueBeforeRedeem);
        console2.log("amount0Out", amount0Out);
        console2.log("amount1Out", amount1Out);
        console2.log("valueAfterRedeem", valueAfterRedeem);
    }
}
