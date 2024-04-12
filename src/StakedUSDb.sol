// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {USDb} from "./USDb.sol";

// Staked USDb Vault on Sei

contract StakedUSDb is Ownable2Step, ERC20Permit, ERC4626 {
    error NonTransferrable();

    constructor(IERC20 _asset, address _admin) ERC20("Staked USDb", "sUSDb") ERC4626(_asset) ERC20Permit("sUSDb") {
        assert(_admin != address(0));
        _transferOwnership(_admin);
    }

    function decimals() public view virtual override(ERC4626, ERC20) returns (uint8) {
        return ERC4626.decimals();
    }

    function _beforeTokenTransfer(address from, address to, uint256) internal override {
        if (from != address(0) && to != address(0)) revert NonTransferrable();
    }
}
