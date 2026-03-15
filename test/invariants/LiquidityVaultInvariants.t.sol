// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";

import {LiquidityVault} from "src/LiquidityVault.sol";
import {FractionalToken} from "src/FractionalToken.sol";
import {MockToken} from "src/mocks/MockToken.sol";

contract VaultHandler is Test {
    LiquidityVault internal immutable vault;
    FractionalToken internal immutable shares;
    MockToken internal immutable token0;
    MockToken internal immutable token1;

    address internal immutable userA;
    address internal immutable userB;
    address internal immutable hook;

    constructor(LiquidityVault vault_, MockToken token0_, MockToken token1_, address hook_) {
        vault = vault_;
        token0 = token0_;
        token1 = token1_;
        shares = vault_.shareToken();
        hook = hook_;
        userA = makeAddr("handlerUserA");
        userB = makeAddr("handlerUserB");

        token0.mint(userA, 1_000_000e18);
        token1.mint(userA, 1_000_000e18);
        token0.mint(userB, 1_000_000e18);
        token1.mint(userB, 1_000_000e18);

        vm.startPrank(userA);
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(userB);
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function depositA(uint256 a0, uint256 a1) external {
        a0 = bound(a0, 1, 1_000e18);
        a1 = bound(a1, 1, 1_000e18);

        vm.prank(userA);
        vault.deposit(a0, a1, userA);
    }

    function depositB(uint256 a0, uint256 a1) external {
        a0 = bound(a0, 1, 1_000e18);
        a1 = bound(a1, 1, 1_000e18);

        vm.prank(userB);
        vault.deposit(a0, a1, userB);
    }

    function accrueFees(uint256 amount) external {
        amount = bound(amount, 1, 1_000e18);

        vm.prank(hook);
        vault.recordAccruedFees(amount);
    }

    function redeemA(uint256 sharesToBurn) external {
        uint256 bal = shares.balanceOf(userA);
        if (bal == 0) return;

        sharesToBurn = bound(sharesToBurn, 1, bal);

        vm.prank(userA);
        vault.redeem(sharesToBurn, userA);
    }

    function redeemB(uint256 sharesToBurn) external {
        uint256 bal = shares.balanceOf(userB);
        if (bal == 0) return;

        sharesToBurn = bound(sharesToBurn, 1, bal);

        vm.prank(userB);
        vault.redeem(sharesToBurn, userB);
    }
}

contract LiquidityVaultInvariantTest is StdInvariant, Test {
    address internal owner = makeAddr("owner");
    address internal hook = makeAddr("hook");

    MockToken internal token0;
    MockToken internal token1;
    LiquidityVault internal vault;
    FractionalToken internal shares;
    VaultHandler internal handler;

    function setUp() external {
        token0 = new MockToken("Token0", "TK0");
        token1 = new MockToken("Token1", "TK1");

        vault = new LiquidityVault(owner, token0, token1, "Fractional LP Share", "FLPS", false);
        shares = vault.shareToken();

        vm.prank(owner);
        vault.setHook(hook);

        handler = new VaultHandler(vault, token0, token1, hook);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = VaultHandler.depositA.selector;
        selectors[1] = VaultHandler.depositB.selector;
        selectors[2] = VaultHandler.accrueFees.selector;
        selectors[3] = VaultHandler.redeemA.selector;
        selectors[4] = VaultHandler.redeemB.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_TotalSharesMatchesSupply() external view {
        LiquidityVault.VaultSnapshot memory snap = vault.snapshot();
        assertEq(snap.totalShares, shares.totalSupply());
    }

    function invariant_VaultValueConservation() external view {
        LiquidityVault.VaultSnapshot memory snap = vault.snapshot();
        assertEq(snap.totalVaultValue, snap.totalLiquidity + snap.accumulatedFees);
    }

    function invariant_SharePriceNeverZero() external view {
        assertGt(vault.sharePriceX96(), 0);
    }
}
