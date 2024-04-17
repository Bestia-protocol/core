// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {TestSetup} from "../TestSetup.t.sol";
import {console2} from "forge-std/Test.sol";

contract HarvestTest is TestSetup {
    // 1. a user deposits USDe to sUSDe vault and then recieves and stakes USDB
    // 2. then add yield on sUSDe and harvest to USDB
    // 3. the user unstakes and withdraws to USDe
    // 4. user2 deposits USDe to sUSDe vault and then receives and stakes USDB
    // 5. then add yield on sUSDe and harvest to USDB

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
        uint256 userEndingBalance = susdb.convertToAssets(
            susdb.balanceOf(user)
        );

        console2.log("userUsdbStartingBalance", userUSDbStartingBalance);
        console2.log("userEndingBalance", userEndingBalance);

        // assert the user has received the correct usdb yield after rounding
        uint256 interestEarned = userEndingBalance - userUSDbStartingBalance;
        assertEq(interestEarned + 2, yield);

        vm.startPrank(user);

        // user unstakes and withdraws to USDe
        susdb.redeem(susdb.balanceOf(user), user, user);

        // assert vault balance is 0 after redeem (with rounding error of 1)
        assertEq(usdb.balanceOf(address(susdb)) - 1, 0);

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

    function test2_WIP() public {
        uint256 amount = 1e18;
        uint256 yield = 1e16; // 1% yield
        usde.mint(user, amount);

        // same setup as testStakeUsdbAndHarvest

        vm.startPrank(user);
        
        assertEq(usdb.balanceOf(address(susdb)), 0);

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

        vm.startPrank(user);

        // user unstakes and withdraws to USDe
        susdb.redeem(susdb.balanceOf(user), user, user);
        redeemer.burn(usdb.balanceOf(user));
        susde.redeem(susde.balanceOf(user), user, user);

        // assert the user has received the correct usde balance after rounding
        uint256 tolerance = 3;
        assertEq(usde.balanceOf(user) + tolerance, amount + yield);

        vm.stopPrank();

        // user2 deposits USDe to sUSDe vault and stakes to get USDb
        usde.mint(user2, amount);
        vm.startPrank(user2);

        usde.approve(address(susde), amount);
        susde.deposit(amount, user2);
        uint256 user2SusdeBalance = susde.balanceOf(user2);
        console2.log("sUSDe balance of user2 after deposit", user2SusdeBalance);

        susde.approve(address(vault), amount);
        vault.stake(susde.balanceOf(user2));
        uint256 user2UsdbStartingBalance = usdb.balanceOf(user2);
        console2.log("usdb balance of user2", user2UsdbStartingBalance);

        // assert that the user2 has received the correct USDb balance
        assertEq(user2UsdbStartingBalance, amount);

        // user2 deposits received USDB to sUSDb
        usdb.approve(address(susdb), user2UsdbStartingBalance);
        susdb.deposit(user2UsdbStartingBalance, user2);
        console2.log("susdb balance of user2", susdb.balanceOf(user2));

        // assert susdb balance of user2 is equal to their USDb deposit
        assertEq(
            user2UsdbStartingBalance,
            susdb.convertToAssets(susdb.balanceOf(user2))
        );

        vm.stopPrank();

        console2.log(
            "usdb balance of susdb before harvest",
            usdb.balanceOf(address(susdb))
        );

        // add yield to sUSDe harvest yield to USDB
        usde.mint(address(susde), yield); // 1e16 USDe
        vault.harvest();

        console2.log(
            "usdb balance of susdb after harvest",
            usdb.balanceOf(address(susdb))
        );

        uint256 user2EndingBalance = susdb.convertToAssets(
            susdb.balanceOf(user2)
        );
        console2.log("user2EndingBalance", user2EndingBalance);

        uint256 totalUsdbinSusdb = usdb.balanceOf(address(susdb));
        console2.log("totalUsdbinSusdb", totalUsdbinSusdb);

        uint256 interestEarned2 = user2EndingBalance - user2UsdbStartingBalance;
        console2.log("interestEarned2", interestEarned2);

        // assert the user2 has received the correct usdb yield after rounding
        assertEq(interestEarned2, yield);
    }
}
