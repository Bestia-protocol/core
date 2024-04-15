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
        susde.deposit(amount, user);

        uint256 userShares = susde.balanceOf(user);
        uint256 userAssets = susde.convertToAssets(userShares);

        // user deposits sUSDe to USDeVault
        vault.stake(susde.balanceOf(user));

        uint256 userUSDbBalance = usdb.balanceOf(user);

        // asserts that user USDb balance is equal to usde value of susde shares
        assertEq(userUSDbBalance, userAssets);
    }

    function testUSDBMintingWithInterest() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        // user deposts USDe to sUSDe vault
        vm.startPrank(user);
        susde.deposit(amount, user);
        vm.stopPrank();

        // more USDe is minted to sUSDe to simulate interest earned
        usde.mint(address(susde), amount);

        uint256 userShares = susde.balanceOf(user);
        uint256 userAssets = susde.convertToAssets(userShares);

        vm.startPrank(user);
        vault.stake(susde.balanceOf(user));
        vm.stopPrank();

        uint256 userUSDbBalance = usdb.balanceOf(user);

        assertEq(userUSDbBalance, userAssets);
    }

    function testBurnUSDbAndGetUSDe() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        // user gets USDB per normal flow
        vm.startPrank(user);
        susde.deposit(amount, user);
        vault.stake(susde.balanceOf(user));

        uint256 userUSDbBalance = usdb.balanceOf(user);

        // user burns USDb to get USDe
        redeemer.burn(userUSDbBalance);
        uint256 susdeReceivedBack = susde.balanceOf(user);
        uint256 userUSDeBalance = susde.convertToAssets(susdeReceivedBack);

        assertEq(userUSDeBalance, amount);
    }

    function testHarvest() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        vm.startPrank(user);
        susde.deposit(amount, user);
        vault.stake(amount);
        vm.stopPrank();

        // simulate 100% profit
        usde.mint(address(susde), amount);
        vault.harvest();

        uint256 profit = amount * susde.balanceOf(address(vault)) - 1e18;
        assertEq(usdb.balanceOf(sink), profit);
        console2.log("Profit: ", profit);
        
    }

    function testMintAndRebalance() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        vm.startPrank(user);
        susde.deposit(amount, user);
        vault.stake(amount);    
        vm.stopPrank();

        uint256 userUSDbBalance = usdb.balanceOf(user);
        console2.log("User USDb balance: ", userUSDbBalance);

        // simulate 100% profit and harvest
        usde.mint(address(susde), amount);
        vault.harvest();

        uint256 interestEarned = usdb.balanceOf(sink);
        console2.log("Interest earned: ", interestEarned);
    }
}
