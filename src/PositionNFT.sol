// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @custom:security-contact security@najnomics.dev
 */
contract PositionNFT is ERC721, Ownable {
    error PositionNFT__ZeroAddress();

    uint256 public nextTokenId;

    constructor(string memory name_, string memory symbol_, address owner_) ERC721(name_, symbol_) Ownable(owner_) {
        if (owner_ == address(0)) revert PositionNFT__ZeroAddress();
    }

    function mint(address to) external onlyOwner returns (uint256 tokenId) {
        if (to == address(0)) revert PositionNFT__ZeroAddress();
        tokenId = ++nextTokenId;
        _safeMint(to, tokenId);
    }
}
