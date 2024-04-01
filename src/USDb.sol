// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract USDb is Ownable2Step, ERC20Burnable, ERC20Permit {
    address public minter;

    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    error OnlyMinter();

    constructor(address admin) ERC20("USDe", "USDe") ERC20Permit("USDe") {
        assert(admin != address(0));
        _transferOwnership(admin);
    }

    function setMinter(address newMinter) external onlyOwner {
        emit MinterUpdated(minter, newMinter);
        minter = newMinter;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != minter) revert OnlyMinter();
        _mint(to, amount);
    }
}
