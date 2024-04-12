// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract MockUSDe is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("USDe", "USDe") {}
}
