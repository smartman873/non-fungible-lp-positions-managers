// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";

import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";

import {Deployers} from "test/utils/Deployers.sol";

import {MockToken} from "src/mocks/MockToken.sol";
import {LiquidityVault} from "src/LiquidityVault.sol";
import {FractionalToken} from "src/FractionalToken.sol";

contract DemoUnichainLifecycleScript is Script, Deployers {
    uint256 internal constant ANVIL_PK_0 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 internal constant DEFAULT_USER_A_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 internal constant DEFAULT_USER_B_PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    uint256 internal constant USER_DEPOSIT_AMOUNT0 = 1_000e18;
    uint256 internal constant USER_DEPOSIT_AMOUNT1 = 1_000e18;
    uint256 internal constant SWAP_AMOUNT_IN = 1e18;
    uint256 internal constant FEE_SIGNAL = 50e18;

    error DemoUnichainLifecycleScript__FundingFailed(address recipient, uint256 amount);

    struct DemoContext {
        address owner;
        address userA;
        address userB;
        MockToken token0;
        MockToken token1;
        LiquidityVault vault;
        FractionalToken shareToken;
        PoolKey poolKey;
    }

    function _etch(address target, bytes memory bytecode) internal override {
        if (block.chainid == 31337) {
            vm.rpc("anvil_setCode", string.concat('["', vm.toString(target), '",', '"', vm.toString(bytecode), '"]'));
        } else {
            revert("DemoUnichainLifecycleScript: unsupported etch");
        }
    }

    function run() external {
        uint256 ownerPk = _ownerPrivateKey();
        uint256 userAPk = _userPrivateKey("USER_A_PRIVATE_KEY", DEFAULT_USER_A_PK);
        uint256 userBPk = _userPrivateKey("USER_B_PRIVATE_KEY", DEFAULT_USER_B_PK);
        deployArtifacts();

        DemoContext memory ctx = _loadContext(ownerPk, userAPk, userBPk);
        _logSystemContext(ctx);

        _phaseFundUsers(ownerPk, ctx.userA, ctx.userB);
        (uint256 sharesA, uint256 sharesB) = _phaseUserDeposits(ctx, userAPk, userBPk);

        uint256 sharePriceBeforeFees = ctx.vault.sharePriceX96();
        BalanceDelta swapDelta = _phaseSwapAndFeeAccrual(ownerPk, ctx);
        uint256 sharePriceAfterFees = ctx.vault.sharePriceX96();

        (uint256 amount0Out, uint256 amount1Out) = _phaseRedeemUserA(ctx, sharesA, userAPk);

        _printSummary(sharesA, sharesB, sharePriceBeforeFees, sharePriceAfterFees, amount0Out, amount1Out, swapDelta);
    }

    function _ownerPrivateKey() internal view returns (uint256) {
        if (block.chainid == 31337) {
            return ANVIL_PK_0;
        }
        return vm.envUint("SEPOLIA_PRIVATE_KEY");
    }

    function _userPrivateKey(string memory key, uint256 fallbackPk) internal view returns (uint256) {
        if (block.chainid == 31337) {
            return fallbackPk;
        }
        return vm.envOr(key, fallbackPk);
    }

    function _loadContext(uint256 ownerPk, uint256 userAPk, uint256 userBPk) internal view returns (DemoContext memory ctx) {
        address token0Address = vm.envAddress("TOKEN0_ADDRESS");
        address token1Address = vm.envAddress("TOKEN1_ADDRESS");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");

        ctx.owner = vm.addr(ownerPk);
        ctx.userA = vm.addr(userAPk);
        ctx.userB = vm.addr(userBPk);

        ctx.token0 = MockToken(token0Address);
        ctx.token1 = MockToken(token1Address);
        ctx.vault = LiquidityVault(vaultAddress);
        ctx.shareToken = ctx.vault.shareToken();

        ctx.poolKey = PoolKey({
            currency0: Currency.wrap(token0Address),
            currency1: Currency.wrap(token1Address),
            fee: 3_000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
    }

    function _logSystemContext(DemoContext memory ctx) internal view {
        console2.log("=== Demo Context ===");
        console2.log("chainid", block.chainid);
        console2.log("owner", ctx.owner);
        console2.log("userA", ctx.userA);
        console2.log("userB", ctx.userB);
        console2.log("token0", address(ctx.token0));
        console2.log("token1", address(ctx.token1));
        console2.log("vault", address(ctx.vault));
        console2.log("hook", address(ctx.poolKey.hooks));
        console2.log("poolManager", address(poolManager));
        console2.log("positionManager", address(positionManager));
        console2.log("router", address(swapRouter));
    }

    function _phaseFundUsers(uint256 ownerPk, address userA, address userB) internal {
        console2.log("=== Phase 1: Fund Demo Users ===");
        vm.startBroadcast(ownerPk);
        uint256 fundingAmount = 0.02 ether;
        (bool fundedA,) = payable(userA).call{value: fundingAmount}("");
        if (!fundedA) {
            revert DemoUnichainLifecycleScript__FundingFailed(userA, fundingAmount);
        }
        (bool fundedB,) = payable(userB).call{value: fundingAmount}("");
        if (!fundedB) {
            revert DemoUnichainLifecycleScript__FundingFailed(userB, fundingAmount);
        }
        vm.stopBroadcast();
    }

    function _phaseUserDeposits(DemoContext memory ctx, uint256 userAPk, uint256 userBPk)
        internal
        returns (uint256 sharesA, uint256 sharesB)
    {
        console2.log("=== Phase 2: User A Deposit ===");
        vm.startBroadcast(userAPk);
        ctx.token0.mint(ctx.userA, USER_DEPOSIT_AMOUNT0);
        ctx.token1.mint(ctx.userA, USER_DEPOSIT_AMOUNT1);
        ctx.token0.approve(address(ctx.vault), type(uint256).max);
        ctx.token1.approve(address(ctx.vault), type(uint256).max);
        sharesA = ctx.vault.deposit(USER_DEPOSIT_AMOUNT0, USER_DEPOSIT_AMOUNT1, ctx.userA);
        vm.stopBroadcast();

        console2.log("userA shares minted", sharesA);
        console2.log("share price after userA", ctx.vault.sharePriceX96());

        console2.log("=== Phase 3: User B Deposit ===");
        vm.startBroadcast(userBPk);
        ctx.token0.mint(ctx.userB, USER_DEPOSIT_AMOUNT0);
        ctx.token1.mint(ctx.userB, USER_DEPOSIT_AMOUNT1);
        ctx.token0.approve(address(ctx.vault), type(uint256).max);
        ctx.token1.approve(address(ctx.vault), type(uint256).max);
        sharesB = ctx.vault.deposit(USER_DEPOSIT_AMOUNT0, USER_DEPOSIT_AMOUNT1, ctx.userB);
        vm.stopBroadcast();

        console2.log("userB shares minted", sharesB);
        console2.log("share price after userB", ctx.vault.sharePriceX96());
    }

    function _phaseSwapAndFeeAccrual(uint256 ownerPk, DemoContext memory ctx) internal returns (BalanceDelta swapDelta) {
        console2.log("=== Phase 4: Swap + Fee Signal ===");

        vm.startBroadcast(ownerPk);

        ctx.token0.mint(ctx.owner, 2_000e18);
        ctx.token1.mint(ctx.owner, 2_000e18);

        // Ensure fee signal has backing balances in the vault.
        ctx.token0.mint(address(ctx.vault), FEE_SIGNAL / 2);
        ctx.token1.mint(address(ctx.vault), FEE_SIGNAL - (FEE_SIGNAL / 2));

        ctx.token0.approve(address(permit2), type(uint256).max);
        ctx.token1.approve(address(permit2), type(uint256).max);
        ctx.token0.approve(address(swapRouter), type(uint256).max);
        ctx.token1.approve(address(swapRouter), type(uint256).max);

        permit2.approve(address(ctx.token0), address(positionManager), type(uint160).max, type(uint48).max);
        permit2.approve(address(ctx.token1), address(positionManager), type(uint160).max, type(uint48).max);
        permit2.approve(address(ctx.token0), address(poolManager), type(uint160).max, type(uint48).max);
        permit2.approve(address(ctx.token1), address(poolManager), type(uint160).max, type(uint48).max);

        swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: SWAP_AMOUNT_IN,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: ctx.poolKey,
            hookData: abi.encode(FEE_SIGNAL),
            receiver: ctx.owner,
            deadline: block.timestamp + 10 minutes
        });

        vm.stopBroadcast();

        console2.log("swap amount0 delta", swapDelta.amount0());
        console2.log("swap amount1 delta", swapDelta.amount1());
        console2.log("share price after fees", ctx.vault.sharePriceX96());
    }

    function _phaseRedeemUserA(DemoContext memory ctx, uint256 sharesA, uint256 userAPk)
        internal
        returns (uint256 amount0Out, uint256 amount1Out)
    {
        console2.log("=== Phase 5: User A Redeem ===");
        vm.startBroadcast(userAPk);
        (amount0Out, amount1Out) = ctx.vault.redeem(sharesA, ctx.userA);
        vm.stopBroadcast();

        console2.log("userA amount0 out", amount0Out);
        console2.log("userA amount1 out", amount1Out);
        console2.log("share price after redeem", ctx.vault.sharePriceX96());
    }

    function _printSummary(
        uint256 sharesA,
        uint256 sharesB,
        uint256 sharePriceBeforeFees,
        uint256 sharePriceAfterFees,
        uint256 amount0Out,
        uint256 amount1Out,
        BalanceDelta swapDelta
    ) internal pure {
        console2.log("=== Judge Summary ===");
        console2.log("initial shares userA", sharesA);
        console2.log("initial shares userB", sharesB);
        console2.log("share price before fees", sharePriceBeforeFees);
        console2.log("share price after fees", sharePriceAfterFees);
        console2.log("userA withdrawal value", amount0Out + amount1Out);
        console2.log("fees signaled", FEE_SIGNAL);
        console2.log("swap delta amount0", swapDelta.amount0());
        console2.log("swap delta amount1", swapDelta.amount1());
    }
}
