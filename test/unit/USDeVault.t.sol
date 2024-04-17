// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {TestSetup} from "../TestSetup.t.sol";
import {console2} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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

        // user deposits USDe to sUSDe vault, and then stakes to get USDb
        vm.startPrank(user);
        susde.deposit(amount, user);
        vault.stake(amount);
        vm.stopPrank();

        // simulate 100% profit and harvest to send to staked USDb vault
        usde.mint(address(susde), amount);

        // check interest earned by the vault's position in USDe terms by subtracing the initial amount
        uint256 interestEarnedInUSDe = susde.convertToAssets(
            susde.balanceOf(address(vault))
        ) - amount;

        console2.log("interestEarnedInUSDe ", interestEarnedInUSDe);

        // harvest the interest to mint USDb to staked USDb vault
        vault.harvest();

        // check the USDb minted by the harvest function
        uint256 usdbMintedByHarvest = usdb.balanceOf(address(susdb));
        console2.log("usdbMinted by harvest function ", usdbMintedByHarvest);

        // assert that the interest earned in USDe is equal to the USDb minted by the harvest function
        assertEq(usdbMintedByHarvest, interestEarnedInUSDe);
    }

    function testMultipleHarvest() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        // user deposits USDe to sUSDe vault, and then stakes to get USDb
        vm.startPrank(user);
        susde.deposit(amount, user);
        vault.stake(amount);
        vm.stopPrank();

        // simulate 100% profit and harvest to send to staked USDb vault
        usde.mint(address(susde), amount);

        // check interest earned by the vault's position in USDe terms by subtracting the initial amount
        uint256 interestEarnedInUSDe = susde.convertToAssets(
            susde.balanceOf(address(vault))
        ) - amount;

        // harvest the interest to mint USDb to staked USDb vault
        vault.harvest();

        // check the USDb minted by the harvest function
        uint256 usdbMintedByHarvest1 = usdb.balanceOf(address(susdb));

        // simulate another 100% profit and harvest to send to staked USDb vault
        usde.mint(address(susde), amount);
        vault.harvest();

        // check the USDb minted by the harvest function
        uint256 usdbMintedByHarvest2 = usdb.balanceOf(address(susdb)) -
            usdbMintedByHarvest1;

        assertEq(
            usdbMintedByHarvest1 + usdbMintedByHarvest2,
            interestEarnedInUSDe * 2
        );
    }

    // finish this later
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
