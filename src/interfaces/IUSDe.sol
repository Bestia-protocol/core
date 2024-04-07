// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IUSDe is IERC20 {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function unstake(address receiver) external;
}
