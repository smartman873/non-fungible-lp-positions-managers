// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";

import {LiquidityVault} from "src/LiquidityVault.sol";
import {FractionalToken} from "src/FractionalToken.sol";
import {PositionNFT} from "src/PositionNFT.sol";
import {MockToken} from "src/mocks/MockToken.sol";

contract LiquidityVaultTest is Test {
    event Deposited(
        address indexed caller,
        address indexed receiver,
        uint256 amount0,
        uint256 amount1,
        uint256 depositValue,
        uint256 sharesMinted
    );

    address internal owner = makeAddr("owner");
    address internal userA = makeAddr("userA");
    address internal userB = makeAddr("userB");
    address internal fakeHook = makeAddr("hook");

    MockToken internal token0;
    MockToken internal token1;
    LiquidityVault internal vault;
    FractionalToken internal shares;

    function setUp() external {
        token0 = new MockToken("Token0", "TK0");
        token1 = new MockToken("Token1", "TK1");

        vault = new LiquidityVault(owner, token0, token1, "Fractional LP Share", "FLPS", true);
        shares = vault.shareToken();

        token0.mint(userA, 1_000_000e18);
        token1.mint(userA, 1_000_000e18);
        token0.mint(userB, 1_000_000e18);
        token1.mint(userB, 1_000_000e18);

        vm.prank(owner);
        vault.setHook(fakeHook);
    }

    function _approveAll(address user) internal {
        vm.startPrank(user);
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function test_ConstructorRevertsOnZeroOwner() external {
        vm.expectRevert(LiquidityVault.LiquidityVault__ZeroAddress.selector);
        new LiquidityVault(address(0), token0, token1, "Fractional LP Share", "FLPS", true);
    }

    function test_ConstructorRevertsOnZeroTokenAddress() external {
        vm.expectRevert(LiquidityVault.LiquidityVault__ZeroAddress.selector);
        new LiquidityVault(owner, MockToken(address(0)), token1, "Fractional LP Share", "FLPS", true);
    }

    function test_ConstructorRevertsOnSameTokenAddress() external {
        vm.expectRevert(LiquidityVault.LiquidityVault__ZeroAddress.selector);
        new LiquidityVault(owner, token0, token0, "Fractional LP Share", "FLPS", true);
    }

    function test_ConstructorWithoutPositionNFT() external {
        LiquidityVault localVault = new LiquidityVault(owner, token0, token1, "Fractional LP Share", "FLPS", false);
        assertEq(address(localVault.positionNFT()), address(0));
    }

    function test_FirstDepositorMints1To1Shares() external {
        _approveAll(userA);

        vm.prank(userA);
        uint256 minted = vault.deposit(100e18, 200e18, userA);

        assertEq(minted, 300e18);
        assertEq(shares.balanceOf(userA), 300e18);

        LiquidityVault.VaultSnapshot memory snap = vault.snapshot();
        assertEq(snap.totalShares, 300e18);
        assertEq(snap.totalLiquidity, 300e18);
        assertEq(snap.accumulatedFees, 0);
    }

    function test_DepositAndRedeemLifecycle() external {
        _approveAll(userA);

        vm.prank(userA);
        vault.deposit(500e18, 500e18, userA);

        token0.mint(address(vault), 50e18);
        token1.mint(address(vault), 50e18);

        vm.prank(fakeHook);
        vault.recordAccruedFees(100e18);

        uint256 balance0Before = token0.balanceOf(userA);
        uint256 balance1Before = token1.balanceOf(userA);
        uint256 userAShares = shares.balanceOf(userA);

        vm.prank(userA);
        (uint256 amount0Out, uint256 amount1Out) = vault.redeem(userAShares, userA);

        assertGt(amount0Out + amount1Out, 1_000e18);
        assertEq(token0.balanceOf(userA), balance0Before + amount0Out);
        assertEq(token1.balanceOf(userA), balance1Before + amount1Out);

        LiquidityVault.VaultSnapshot memory snap = vault.snapshot();
        assertEq(snap.totalShares, 0);
        assertEq(snap.totalVaultValue, 0);
    }

    function test_DepositRevertsOnZeroReceiver() external {
        _approveAll(userA);

        vm.prank(userA);
        vm.expectRevert(LiquidityVault.LiquidityVault__ZeroAddress.selector);
        vault.deposit(1e18, 1e18, address(0));
    }

    function test_DepositRevertsOnZeroAmount() external {
        _approveAll(userA);

        vm.prank(userA);
        vm.expectRevert(LiquidityVault.LiquidityVault__ZeroDeposit.selector);
        vault.deposit(0, 0, userA);
    }

    function test_RedeemAfterLoss() external {
        _approveAll(userA);

        vm.prank(userA);
        vault.deposit(1_000e18, 0, userA);

        vm.prank(owner);
        vault.recordLoss(250e18);

        vm.prank(userA);
        (uint256 amount0Out, uint256 amount1Out) = vault.redeem(1_000e18, userA);

        assertEq(amount0Out + amount1Out, 750e18);
    }

    function test_RedeemRevertsOnZeroReceiver() external {
        _approveAll(userA);

        vm.prank(userA);
        vault.deposit(100e18, 100e18, userA);

        vm.prank(userA);
        vm.expectRevert(LiquidityVault.LiquidityVault__ZeroAddress.selector);
        vault.redeem(100e18, address(0));
    }

    function test_RedeemRevertsOnZeroShares() external {
        vm.prank(userA);
        vm.expectRevert(LiquidityVault.LiquidityVault__ZeroShares.selector);
        vault.redeem(0, userA);
    }

    function test_RedeemRevertsOnInvalidSharesForCaller() external {
        _approveAll(userA);

        vm.prank(userA);
        vault.deposit(100e18, 100e18, userA);

        vm.prank(userB);
        vm.expectRevert(LiquidityVault.LiquidityVault__InvalidShareAmount.selector);
        vault.redeem(1, userB);
    }

    function test_LastRedeemerZeroesState() external {
        _approveAll(userA);
        _approveAll(userB);

        vm.prank(userA);
        vault.deposit(400e18, 100e18, userA);

        vm.prank(userB);
        vault.deposit(300e18, 200e18, userB);

        uint256 userAShares = shares.balanceOf(userA);
        vm.prank(userA);
        vault.redeem(userAShares, userA);

        uint256 userBShares = shares.balanceOf(userB);
        vm.prank(userB);
        vault.redeem(userBShares, userB);

        LiquidityVault.VaultSnapshot memory snap = vault.snapshot();
        assertEq(snap.totalShares, 0);
        assertEq(snap.totalVaultValue, 0);
        assertEq(snap.sharePriceX96, 2 ** 96);
    }

    function test_SetHookRevertsOnZeroAddress() external {
        LiquidityVault localVault = new LiquidityVault(owner, token0, token1, "Fractional LP Share", "FLPS", false);
        vm.prank(owner);
        vm.expectRevert(LiquidityVault.LiquidityVault__ZeroAddress.selector);
        localVault.setHook(address(0));
    }

    function test_SetHookRevertsWhenAlreadySet() external {
        vm.prank(owner);
        vm.expectRevert(LiquidityVault.LiquidityVault__HookAlreadySet.selector);
        vault.setHook(makeAddr("newHook"));
    }

    function test_RoundingEdgeStillMintsShare() external {
        _approveAll(userA);
        _approveAll(userB);

        vm.prank(userA);
        vault.deposit(1_000_000e18, 1_000_000e18, userA);

        vm.prank(fakeHook);
        vault.recordAccruedFees(1_000_000e18);

        vm.prank(userB);
        uint256 minted = vault.deposit(1, 0, userB);

        assertEq(minted, 1);
        assertEq(shares.balanceOf(userB), 1);
    }

    function test_DonateFeesAccruesAndUpdatesSharePrice() external {
        _approveAll(userA);
        vm.prank(userA);
        vault.deposit(100e18, 100e18, userA);

        uint256 sharePriceBefore = vault.sharePriceX96();

        vm.startPrank(userB);
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vault.donateFees(10e18, 20e18);
        vm.stopPrank();

        LiquidityVault.VaultSnapshot memory snap = vault.snapshot();
        assertEq(snap.accumulatedFees, 30e18);
        assertGt(vault.sharePriceX96(), sharePriceBefore);
    }

    function test_DonateFeesRevertsOnZeroAmount() external {
        vm.prank(userA);
        vm.expectRevert(LiquidityVault.LiquidityVault__ZeroDeposit.selector);
        vault.donateFees(0, 0);
    }

    function test_RecordAccruedFeesRevertsForUnauthorizedCaller() external {
        vm.prank(userA);
        vm.expectRevert(LiquidityVault.LiquidityVault__UnauthorizedHook.selector);
        vault.recordAccruedFees(1e18);
    }

    function test_RecordAccruedFeesRevertsOnZeroFee() external {
        vm.prank(fakeHook);
        vm.expectRevert(LiquidityVault.LiquidityVault__ZeroDeposit.selector);
        vault.recordAccruedFees(0);
    }

    function test_SyncLiquidityRevertsForUnauthorizedCaller() external {
        vm.prank(userA);
        vm.expectRevert(LiquidityVault.LiquidityVault__UnauthorizedHook.selector);
        vault.syncLiquidity(123e18);
    }

    function test_SyncLiquidityUpdatesState() external {
        vm.prank(fakeHook);
        vault.syncLiquidity(777e18);

        LiquidityVault.VaultSnapshot memory snap = vault.snapshot();
        assertEq(snap.totalLiquidity, 777e18);
    }

    function test_RecordLossRevertsOnZeroLoss() external {
        vm.prank(owner);
        vm.expectRevert(LiquidityVault.LiquidityVault__ZeroDeposit.selector);
        vault.recordLoss(0);
    }

    function test_RecordLossRevertsWhenExceedingLiquidity() external {
        _approveAll(userA);
        vm.prank(userA);
        vault.deposit(10e18, 0, userA);

        vm.prank(owner);
        vm.expectRevert(LiquidityVault.LiquidityVault__LossExceedsLiquidity.selector);
        vault.recordLoss(11e18);
    }

    function test_PreviewDepositAndRedeem() external {
        _approveAll(userA);

        uint256 previewShares = vault.previewDeposit(25e18, 75e18);
        assertEq(previewShares, 100e18);

        vm.prank(userA);
        vault.deposit(25e18, 75e18, userA);

        uint256 previewWithdraw = vault.previewRedeem(20e18);
        assertEq(previewWithdraw, 20e18);
    }

    function test_PreviewDepositRevertsOnZeroAmount() external {
        vm.expectRevert();
        vault.previewDeposit(0, 0);
    }

    function test_PreviewRedeemRevertsOnZeroShares() external {
        vm.expectRevert();
        vault.previewRedeem(0);
    }

    function test_PositionNFTMintPath() external {
        PositionNFT nft = vault.positionNFT();
        vm.prank(owner);
        uint256 tokenId = nft.mint(owner);

        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(tokenId), owner);
    }

    function test_RedeemCapsWithdrawToAvailableBalances() external {
        _approveAll(userA);

        vm.prank(userA);
        vault.deposit(100e18, 100e18, userA);

        // Accounting says there are fees, but balances are not physically funded.
        vm.prank(fakeHook);
        vault.recordAccruedFees(100e18);

        // Drain all token balances to enforce withdraw cap branch.
        uint256 vaultBal0 = token0.balanceOf(address(vault));
        uint256 vaultBal1 = token1.balanceOf(address(vault));
        vm.prank(address(vault));
        token0.transfer(owner, vaultBal0);
        vm.prank(address(vault));
        token1.transfer(owner, vaultBal1);

        uint256 userShares = shares.balanceOf(userA);
        vm.prank(userA);
        (uint256 amount0Out, uint256 amount1Out) = vault.redeem(userShares, userA);

        assertEq(amount0Out + amount1Out, 0);
    }

    function test_UnauthorizedShareMintReverts() external {
        vm.prank(userA);
        vm.expectRevert();
        shares.mint(userA, 1);
    }

    function test_UnauthorizedHookUpdateReverts() external {
        vm.prank(userA);
        vm.expectRevert();
        vault.setHook(userA);
    }

    function test_EventIndexingForDeposit() external {
        _approveAll(userA);

        vm.expectEmit(true, true, false, true, address(vault));
        emit Deposited(userA, userA, 10e18, 20e18, 30e18, 30e18);

        vm.prank(userA);
        vault.deposit(10e18, 20e18, userA);
    }

    function test_ZeroLiquidityRedeemReverts() external {
        vm.prank(userA);
        vm.expectRevert();
        vault.redeem(1e18, userA);
    }

    function testFuzz_DepositRedeemConservation(uint96 a0, uint96 a1, uint96 b0, uint96 b1, uint96 fees) external {
        a0 = uint96(bound(a0, 1, 1_000_000e6));
        a1 = uint96(bound(a1, 1, 1_000_000e6));
        b0 = uint96(bound(b0, 1, 1_000_000e6));
        b1 = uint96(bound(b1, 1, 1_000_000e6));
        fees = uint96(bound(fees, 0, 1_000_000e6));

        _approveAll(userA);
        _approveAll(userB);

        vm.prank(userA);
        vault.deposit(a0, a1, userA);

        vm.prank(userB);
        vault.deposit(b0, b1, userB);

        if (fees > 0) {
            token0.mint(address(vault), fees / 2);
            token1.mint(address(vault), fees - (fees / 2));
            vm.prank(fakeHook);
            vault.recordAccruedFees(fees);
        }

        uint256 valueBefore = vault.totalVaultValue();
        uint256 userAShares = shares.balanceOf(userA);

        vm.prank(userA);
        vault.redeem(userAShares, userA);

        uint256 userBShares = shares.balanceOf(userB);
        vm.prank(userB);
        vault.redeem(userBShares, userB);

        LiquidityVault.VaultSnapshot memory snap = vault.snapshot();
        assertGe(valueBefore, fees);
        assertEq(snap.totalVaultValue, 0);
        assertEq(shares.totalSupply(), snap.totalShares);
    }
}
