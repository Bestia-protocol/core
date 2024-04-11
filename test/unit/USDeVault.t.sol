// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {TestSetup} from "../TestSetup.t.sol";
import {console2} from "forge-std/Test.sol";

contract USDeVaultTest is TestSetup {
    function testMintUSDbByStakingUSDe() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        vm.startPrank(user);

        // user deposts USDe to sUSDe vault
        usde.approve(address(susde), amount);
        susde.deposit(amount, user);

        uint256 userShares = susde.balanceOf(user);
        uint256 userAssets = susde.convertToAssets(userShares);
        console2.log("user sUSDe Shares", userShares);
        console2.log("user USDe Assets after convertToAssets()", userAssets);

        // user deposits sUSDe to USDeVault
        susde.approve(address(vault), amount);
        vault.stake(susde.balanceOf(user));

        uint256 userUSDbBalance = usdb.balanceOf(user);

        console2.log("user USDb balance", userUSDbBalance);

        // asserts that user USDb balance is equal to usde value of susde shares
        assertEq(userUSDbBalance, userAssets);
    }

    function testBurnUSDbAndGetUSDe() external {
        // ipleemnt code here
    }
}
