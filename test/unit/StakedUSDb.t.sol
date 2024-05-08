// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {console2} from "forge-std/Test.sol";
import {TestSetup} from "../TestSetup.t.sol";

contract StakedUSDbTest is TestSetup {
    // test minting sUSDb
    function testMintSusdb() external {
        uint256 amount = 1e18;

        // router mints usdb to user
        vm.startPrank(address(router));
        usdb.mint(user, amount);
        vm.stopPrank();

        uint256 userBalance = susdb.convertToShares(amount);

        // user deposits usdb to sUSDb
        vm.startPrank(user);
        usdb.approve(address(susdb), amount);
        susdb.deposit(amount, user);

        uint256 userShares = susdb.balanceOf(user);

        assertEq(userShares, userBalance);
    }

    // test nonTransferable
    function testNonTransferable() external {
        uint256 amount = 1e18;

        // router mints usdb to user
        vm.startPrank(address(router));
        usdb.mint(user, amount);
        vm.stopPrank();

        vm.startPrank(user);

        usdb.approve(address(susdb), amount);
        susdb.deposit(usdb.balanceOf(user), user);

        susdb.approve(address(user2), amount);

        // user2 tries to transfer sUSDb from user
        vm.expectRevert();
        susdb.transfer(user2, amount);

        vm.stopPrank();
    }

    function testSocialisedLosses() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        vm.startPrank(user);
        usde.approve(user, type(uint256).max);
        susde.deposit(amount, user);
        assertEq(susde.balanceOf(user), amount); // share price = 1
        vault.stake(amount);
        vm.stopPrank();

        vm.prank(address(susde));
        usde.burn(amount * 10 / 100); // share price = 0.9

        vm.prank(user);
        redeemer.burn(amount);

        //assertEq(usde.balanceOf(user), amount); // share price = 1
    }
}
