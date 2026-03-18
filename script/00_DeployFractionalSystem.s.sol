// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";

import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";

import {Deployers} from "test/utils/Deployers.sol";

import {MockToken} from "src/mocks/MockToken.sol";
import {LiquidityVault} from "src/LiquidityVault.sol";
import {FractionalLPHook} from "src/FractionalLPHook.sol";
import {ILiquidityVault} from "src/interfaces/ILiquidityVault.sol";

contract DeployFractionalSystemScript is Script, Deployers {
    using CurrencyLibrary for Currency;

    error DeployFractionalSystemScript__HookAddressMismatch();

    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint256 internal constant ANVIL_PK_0 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function _etch(address target, bytes memory bytecode) internal override {
        if (block.chainid == 31337) {
            vm.rpc("anvil_setCode", string.concat('["', vm.toString(target), '",', '"', vm.toString(bytecode), '"]'));
        } else {
            revert("DeployFractionalSystemScript: unsupported etch");
        }
    }

    function run() external {
        uint256 deployerPrivateKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerPrivateKey);

        // Permit2 must exist at canonical address before deploying v4 artifacts.
        deployPermit2();

        vm.startBroadcast(deployerPrivateKey);

        deployPoolManager();
        deployPositionManager();
        deployRouter();

        MockToken token0 = new MockToken("Mock USDC", "mUSDC");
        MockToken token1 = new MockToken("Mock WETH", "mWETH");

        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        token0.mint(deployer, 2_000_000e18);
        token1.mint(deployer, 2_000_000e18);

        token0.approve(address(permit2), type(uint256).max);
        token1.approve(address(permit2), type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);

        permit2.approve(address(token0), address(positionManager), type(uint160).max, type(uint48).max);
        permit2.approve(address(token1), address(positionManager), type(uint160).max, type(uint48).max);
        permit2.approve(address(token0), address(poolManager), type(uint160).max, type(uint48).max);
        permit2.approve(address(token1), address(poolManager), type(uint160).max, type(uint48).max);

        LiquidityVault vault = new LiquidityVault(
            deployer, IERC20(address(token0)), IERC20(address(token1)), "Fractional LP Share", "FLPS", true
        );

        bytes memory constructorArgs = abi.encode(poolManager, ILiquidityVault(address(vault)), deployer);
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);

        (address expectedHookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_FACTORY, flags, type(FractionalLPHook).creationCode, constructorArgs);

        FractionalLPHook hook = new FractionalLPHook{salt: salt}(
            IPoolManager(address(poolManager)), ILiquidityVault(address(vault)), deployer
        );

        if (address(hook) != expectedHookAddress) {
            revert DeployFractionalSystemScript__HookAddressMismatch();
        }

        vault.setHook(address(hook));

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3_000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });

        poolManager.initialize(poolKey, SQRT_PRICE_1_1);
        hook.registerPool(poolKey);
        _seedInitialLiquidity(poolKey, deployer);

        vm.stopBroadcast();

        console2.log("deployer", deployer);
        console2.log("token0", address(token0));
        console2.log("token1", address(token1));
        console2.log("vault", address(vault));
        console2.log("hook", address(hook));
        console2.log("poolManager", address(poolManager));
        console2.log("positionManager", address(positionManager));
    }

    function _deployerPrivateKey() internal view returns (uint256) {
        if (block.chainid == 31337) {
            return ANVIL_PK_0;
        }
        return vm.envUint("SEPOLIA_PRIVATE_KEY");
    }

    function _seedInitialLiquidity(PoolKey memory poolKey, address recipient) internal {
        int24 tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);
        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP), uint8(Actions.SWEEP)
        );

        bytes[] memory params = new bytes[](4);
        params[0] = abi.encode(
            poolKey, tickLower, tickUpper, liquidityAmount, amount0Expected + 1, amount1Expected + 1, recipient, bytes("")
        );
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        params[2] = abi.encode(poolKey.currency0, recipient);
        params[3] = abi.encode(poolKey.currency1, recipient);

        positionManager.modifyLiquidities(abi.encode(actions, params), type(uint256).max);
    }
}
