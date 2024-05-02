// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IsUSDe} from "src/interfaces/IsUSDe.sol";

// Mock ERC4626 Vault for testing
// Gradually implement functionality of StakedUSDeV2.sol & (inherited) StakedUSDe.sol as needed to match function calls you need

contract MockEthenaVault is ERC4626 {
    using Math for uint256;

    constructor(address _usde) ERC20("Staked USDe", "susde") ERC4626(IERC20(_usde)) {}
}
