// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {TestSetup} from "../TestSetup.t.sol";
import {console2} from "forge-std/Test.sol";

contract HarvestTest is TestSetup {
    // tests a user deposits USDe to sUSDe vault and the stakes USDB
    // then add yield on sUSDe and harvest to USDB

    function testStakeAndHarvest() public {
        uint256 amount = 1e18;
        uint256 yield = 1e16; // 1% yield
        usde.mint(user, amount);

        console2.log(
            "starting usdb balance of susdb",
            usdb.balanceOf(address(susdb))
        );

        // user deposits USDe to sUSDe vault and stakes to get USDB
        vm.startPrank(user);
        susde.deposit(amount, user);
        vault.stake(susde.balanceOf(user));

        usdb.approve(address(susdb), usdb.balanceOf(user));
        susdb.deposit(usdb.balanceOf(user), user);
        console2.log(
            "usdb balance of susdb after user deposit",
            usdb.balanceOf(address(susdb))
        );
        console2.log("susdb balance of user", susdb.balanceOf(user));

        vm.stopPrank();

        // add yield to sUSDe
        usde.mint(address(susde), yield);

        // harvest yield to USDB
        vault.harvest();

        console2.log(
            "usdb balance of susdb after harvest",
            usdb.balanceOf(address(susdb))
        );
    }
}
