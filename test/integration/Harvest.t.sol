// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {TestSetup} from "../TestSetup.t.sol";
import {console2} from "forge-std/Test.sol";

contract HarvestTest is TestSetup {
    // tests a user deposits USDe to sUSDe vault and the stakes USDB
    // then add yield on sUSDe and harvest to USDB

    function testStakeUsdbAndHarvest() public {
        uint256 amount = 1e18;
        uint256 yield = 1e16; // 1% yield
        usde.mint(user, amount);

        vm.startPrank(user);

        // user deposits USDe to sUSDe vault and stakes to get USDB
        susde.deposit(amount, user);
        vault.stake(susde.balanceOf(user));

        // user deposits received USDB to sUSDb
        uint256 userStartingBalance = usdb.balanceOf(user);
        usdb.approve(address(susdb), userStartingBalance);
        susdb.deposit(usdb.balanceOf(user), user);

        vm.stopPrank();

        // add yield to sUSDe harvest yield to USDB
        usde.mint(address(susde), yield);
        vault.harvest();

        // user available usdb balance should be increased by the yield
        uint256 userEndingBalance = usdb.balanceOf(address(susdb));

        console2.log("userStartingBalance", userStartingBalance);
        console2.log("userEndingBalance", userEndingBalance);

        uint256 interestEarned = userEndingBalance - userStartingBalance;

        // assert the user has received the correct usdb yield after rounding
        assertEq(interestEarned + 1, yield);
    }
}
