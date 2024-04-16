// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {TestSetup} from "../TestSetup.t.sol";
import {console2} from "forge-std/Test.sol";

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
}
