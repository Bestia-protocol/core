// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

interface Isusde is IERC4626 {
    function unstake(address receiver) external;
}
