// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @custom:security-contact security@najnomics.dev
 */
contract FractionalToken is ERC20, Ownable {
    error FractionalToken__ZeroAddress();

    constructor(string memory name_, string memory symbol_, address owner_) ERC20(name_, symbol_) Ownable(msg.sender) {
        if (owner_ == address(0)) revert FractionalToken__ZeroAddress();
        _transferOwnership(owner_);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert FractionalToken__ZeroAddress();
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
