// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {FractionalToken} from "src/FractionalToken.sol";
import {PositionNFT} from "src/PositionNFT.sol";

contract FractionalTokenTest is Test {
    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    function test_ConstructorSetsOwner() external {
        FractionalToken token = new FractionalToken("Fractional", "FRAC", owner);
        assertEq(token.owner(), owner);
    }

    function test_ConstructorRevertsOnZeroOwner() external {
        vm.expectRevert(FractionalToken.FractionalToken__ZeroAddress.selector);
        new FractionalToken("Fractional", "FRAC", address(0));
    }

    function test_MintAndBurnFromOwner() external {
        FractionalToken token = new FractionalToken("Fractional", "FRAC", owner);

        vm.prank(owner);
        token.mint(user, 100e18);
        assertEq(token.balanceOf(user), 100e18);

        vm.prank(owner);
        token.burnFrom(user, 40e18);
        assertEq(token.balanceOf(user), 60e18);
    }

    function test_MintRevertsOnZeroRecipient() external {
        FractionalToken token = new FractionalToken("Fractional", "FRAC", owner);

        vm.prank(owner);
        vm.expectRevert(FractionalToken.FractionalToken__ZeroAddress.selector);
        token.mint(address(0), 1);
    }

    function test_MintRevertsForNonOwner() external {
        FractionalToken token = new FractionalToken("Fractional", "FRAC", owner);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        token.mint(user, 1);
    }

    function test_BurnRevertsForNonOwner() external {
        FractionalToken token = new FractionalToken("Fractional", "FRAC", owner);

        vm.prank(owner);
        token.mint(user, 1);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        token.burnFrom(user, 1);
    }
}

contract PositionNFTTest is Test {
    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    function test_ConstructorSetsOwner() external {
        PositionNFT nft = new PositionNFT("Position", "POS", owner);
        assertEq(nft.owner(), owner);
    }

    function test_ConstructorRevertsOnZeroOwner() external {
        vm.expectRevert(PositionNFT.PositionNFT__ZeroAddress.selector);
        new PositionNFT("Position", "POS", address(0));
    }

    function test_MintByOwnerIncrementsTokenId() external {
        PositionNFT nft = new PositionNFT("Position", "POS", owner);

        vm.prank(owner);
        uint256 tokenId1 = nft.mint(user);
        vm.prank(owner);
        uint256 tokenId2 = nft.mint(owner);

        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(nft.ownerOf(tokenId1), user);
        assertEq(nft.ownerOf(tokenId2), owner);
    }

    function test_MintRevertsOnZeroRecipient() external {
        PositionNFT nft = new PositionNFT("Position", "POS", owner);

        vm.prank(owner);
        vm.expectRevert(PositionNFT.PositionNFT__ZeroAddress.selector);
        nft.mint(address(0));
    }

    function test_MintRevertsForNonOwner() external {
        PositionNFT nft = new PositionNFT("Position", "POS", owner);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        nft.mint(user);
    }
}
