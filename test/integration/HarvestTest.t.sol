// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {console2} from "forge-std/Test.sol";
import {TestSetup} from "../TestSetup.t.sol";

contract HarvestTest is TestSetup {
    // 1. a user deposits USDe to sUSDe vault and then recieves and stakes USDB
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
        uint256 userEndingBalance = susdb.convertToAssets(susdb.balanceOf(user));

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

    // 0. large initial deposit to susde to simulate active vault
    // 1. a user deposits USDe to sUSDe vault and then recieves and stakes USDB
    // 2. then add yield on sUSDe and harvest to USDB
    // 3. the user unstakes and withdraws to USDe
    // 4. user2 deposits USDe to sUSDe vault and then receives and stakes USDB
    // 5. then add yield on sUSDe and harvest to USDB
    function testHarvestForSecondUser() public {
        uint256 susdeVaultBalance = 100e18;
        uint256 amount = 1e18;
        uint256 yield = 1e16; // 1% yield

        /**
         * @dev large initial deposit to susde to simulate active vault
         */

        usde.mint(user3, susdeVaultBalance);
        vm.startPrank(user3);
        usde.approve(address(susde), susdeVaultBalance);
        susde.deposit(susdeVaultBalance, user3);
        vm.stopPrank();

        /**
         * @dev a user deposits USDe to sUSDe vault and then recieves and stakes USDB
         * then add yield on sUSDe and harvest to USDB
         * the user unstakes and withdraws to USDe
         * assert that the user has received the correct usde balance after rounding
         */

        // same setup as testStakeUsdbAndHarvest
        usde.mint(user, amount);
        vm.startPrank(user);

        // assert vault is empty to start
        assertEq(usdb.balanceOf(address(susdb)), 0);

        // user deposits USDe to sUSDe vault and stakes to get USDB
        susde.deposit(amount, user);
        vault.stake(susde.balanceOf(user));

        // user deposits received USDB to sUSDb
        uint256 userUSDbStartingBalance = usdb.balanceOf(user);
        usdb.approve(address(susdb), userUSDbStartingBalance);
        susdb.deposit(usdb.balanceOf(user), user);

        // assert the total in vault is equal to the user's USDb deposit
        assertEq(usdb.balanceOf(address(susdb)), amount);

        vm.stopPrank();

        // add yield to sUSDe and harvest yield to USDB
        usde.mint(address(susde), yield);

        // check the usde value of the vault shares minus the user's deposit
        uint256 addedYield = susde.convertToAssets(susde.balanceOf(address(vault))) - amount;

        // harvest the added yield to USDb
        vault.harvest();

        // assert total in susdb is equal to the user's USDb deposit + yield after harvesting
        assertEq(usdb.balanceOf(address(susdb)), amount + addedYield);

        console2.log("usdb in susdb", usdb.balanceOf(address(susdb)));

        vm.startPrank(user);

        // user unstakes and withdraws to USDe
        susdb.redeem(susdb.balanceOf(user), user, user);

        // assert vault balance is 0 after redeem (with rounding error of 1)
        assertEq(usdb.balanceOf(address(susdb)) - 1, 0);

        redeemer.burn(usdb.balanceOf(user));
        susde.redeem(susde.balanceOf(user), user, user);

        // assert the user has received the correct usde balance after rounding
        uint256 tolerance = 2;
        assertEq(usde.balanceOf(user) + tolerance, amount + addedYield);

        vm.stopPrank();

        /**
         * @dev user2 deposits USDe to sUSDe vault and then receives and stakes USDB
         * then add yield on sUSDe and harvest to USDB
         */

        usde.mint(user2, amount);
        vm.startPrank(user2);

        // user2 deposits USDe to sUSDe vault and stakes to get USDb
        usde.approve(address(susde), amount);
        susde.deposit(amount, user2);
        susde.approve(address(vault), amount);
        vault.stake(susde.balanceOf(user2));

        // assert that the user2 has received the correct USDb balance
        assertEq(usdb.balanceOf(user2) + 1, amount);
        uint256 user2UsdbStartingBalance = usdb.balanceOf(user2);

        // user2 deposits received USDB to sUSDb
        usdb.approve(address(susdb), usdb.balanceOf(user2));
        susdb.deposit(usdb.balanceOf(user2), user2);

        // assert susdb balance of user2 is equal to their USDb deposit
        assertEq(user2UsdbStartingBalance, susdb.convertToAssets(susdb.balanceOf(user2)) + 1);

        vm.stopPrank();

        // add yield to sUSDe harvest yield to USDB
        usde.mint(address(susde), yield); // 1e16 USDe

        // amount of yield to harvest
        uint256 yieldDueToUser2 = susde.convertToAssets(susde.balanceOf(address(vault))) - amount;

        vault.harvest();

        console2.log("usdb balance of susdb after harvest", usdb.balanceOf(address(susdb)));

        uint256 user2EndingBalance = susdb.convertToAssets(susdb.balanceOf(user2));
        console2.log("user2EndingBalance", user2EndingBalance);

        // uint256 totalUsdbinSusdb = usdb.balanceOf(address(susdb));
        // console2.log("totalUsdbinSusdb", totalUsdbinSusdb);

        uint256 interestEarned2 = user2EndingBalance - user2UsdbStartingBalance;
        console2.log("interestEarned2", interestEarned2);

        // assert user2 has received the correct usdb yield after rounding
        assertEq(interestEarned2 + 2, yieldDueToUser2);
    }
}
