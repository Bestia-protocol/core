// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {MockUSDe} from "./MockUSDe.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Mock4626Vault is ERC4626 {
    MockUSDe public usde;

    constructor(MockUSDe _usde) 
    ERC20("Staked USDe", "sUSDe")
    ERC4626(IERC20(_usde)) 
    {
        usde = _usde;
    }
}