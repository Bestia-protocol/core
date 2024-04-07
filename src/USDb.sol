// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract USDb is Ownable2Step, ERC20Burnable, ERC20Permit {
    mapping(address => bool) public minters;

    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    error RestrictedToMinters();

    constructor(address admin) ERC20("USDe", "USDe") ERC20Permit("USDe") {
        assert(admin != address(0));
        _transferOwnership(admin);
    }

    modifier onlyMinter() {
        if (!minters[msg.sender]) revert RestrictedToMinters();
        _;
    }

    function addMinter(address minter) external onlyOwner {
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    function removeMinter(address minter) external onlyOwner {
        delete minters[minter];
        emit MinterRemoved(minter);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(uint256 amount) public override onlyMinter {
        _burn(msg.sender, amount);
    }
}
