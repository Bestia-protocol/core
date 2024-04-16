// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {TestSetup} from "../TestSetup.t.sol";
import {console2} from "forge-std/Test.sol";

contract HarvestTest is TestSetup {
    // 1. a user deposits USDe to sUSDe vault and the stakes USDB
    // 2. then add yield on sUSDe and harvest to USDB
    // 3. the user unstakes and withdraws to USDe

    function testStakeUsdbAndHarvest() public {
        uint256 amount = 1e18;
        uint256 yield = 1e16; // 1% yield
        usde.mint(user, amount);

        vm.startPrank(user);

        // user deposits USDe to sUSDe vault and stakes to get USDB
        susde.deposit(amount, user);
        vault.stake(susde.balanceOf(user));

        // user deposits received USDB to sUSDb
        uint256 userUSDbStartingBalance = usdb.balanceOf(user);
        usdb.approve(address(susdb), userUSDbStartingBalance);
        susdb.deposit(usdb.balanceOf(user), user);

        vm.stopPrank();

        // add yield to sUSDe harvest yield to USDB
        usde.mint(address(susde), yield);
        vault.harvest();

        // user available usdb balance should be increased by the yield
        uint256 userEndingBalance = usdb.balanceOf(address(susdb));

        console2.log("userStartingBalance", userUSDbStartingBalance);
        console2.log("userEndingBalance", userEndingBalance);

        // assert the user has received the correct usdb yield after rounding
        uint256 interestEarned = userEndingBalance - userUSDbStartingBalance;
        assertEq(interestEarned + 1, yield);

        vm.startPrank(user);

        // user unstakes and withdraws to USDe
        susdb.redeem(susdb.balanceOf(user), user, user);
        uint256 usdbBalance = usdb.balanceOf(user);
        console2.log("usdb.balanceOf(user) after redeem", usdbBalance);
        
        // burn the USDB to receive sUSDe
        redeemer.burn(usdbBalance);
        uint256 susdeBalance = susde.balanceOf(user);
        console2.log("susde.balanceOf(user) after burning USDb", susdeBalance);

        // redeem sUSDe to USDe
        susde.redeem(susde.balanceOf(user), user, user);
        uint256 usdeBalance = usde.balanceOf(user);
        console2.log("usde.balanceOf(user) after redeem", usdeBalance);

        vm.stopPrank();

        // assert the user has received the correct usde balance after rounding
        uint256 tolerance = 3;
        assertApproxEqAbs(usdeBalance, amount + yield, tolerance);
    }
}
