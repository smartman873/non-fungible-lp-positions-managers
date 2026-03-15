// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";

import {Deployers} from "test/utils/Deployers.sol";
import {EasyPosm} from "test/utils/libraries/EasyPosm.sol";

import {MockToken} from "src/mocks/MockToken.sol";
import {LiquidityVault} from "src/LiquidityVault.sol";
import {FractionalLPHook} from "src/FractionalLPHook.sol";
import {ILiquidityVault} from "src/interfaces/ILiquidityVault.sol";

contract DeployFractionalSystemScript is Script, Deployers {
    using EasyPosm for IPositionManager;
    using CurrencyLibrary for Currency;

    error DeployFractionalSystemScript__HookAddressMismatch();

    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function _etch(address target, bytes memory bytecode) internal override {
        if (block.chainid == 31337) {
            vm.rpc("anvil_setCode", string.concat('["', vm.toString(target), '",', '"', vm.toString(bytecode), '"]'));
        } else {
            revert("DeployFractionalSystemScript: unsupported etch");
        }
    }

    function run() external {
        address deployer = _deployerAddress();

        // Permit2 must exist at canonical address before deploying v4 artifacts.
        deployPermit2();

        vm.startBroadcast(deployer);

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

        vm.stopBroadcast();

        console2.log("deployer", deployer);
        console2.log("token0", address(token0));
        console2.log("token1", address(token1));
        console2.log("vault", address(vault));
        console2.log("hook", address(hook));
        console2.log("poolManager", address(poolManager));
        console2.log("positionManager", address(positionManager));
    }

    function _deployerAddress() internal returns (address) {
        address[] memory wallets = vm.getWallets();
        if (wallets.length > 0) {
            return wallets[0];
        }
        return msg.sender;
    }
}
