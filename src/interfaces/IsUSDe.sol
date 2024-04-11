// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

interface IsUSDe is IERC4626 {
    function unstake(address receiver) external;
}
