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

    function testUSDBMintingWithInterest() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        // user deposts USDe to sUSDe vault
        vm.startPrank(user);
        usde.approve(address(susde), amount);
        susde.deposit(amount, user);
        vm.stopPrank();

        // more USDe is minted to sUSDe to simulate interest earned
        usde.mint(address(susde), amount);

        uint256 userShares = susde.balanceOf(user);
        uint256 userAssets = susde.convertToAssets(userShares);
        console2.log("user sUSDe Shares", userShares);
        console2.log("user USDe Assets after convertToAssets()", userAssets);

        vm.startPrank(user);
        susde.approve(address(vault), amount);
        vault.stake(susde.balanceOf(user));
        vm.stopPrank();

        uint256 userUSDbBalance = usdb.balanceOf(user);
        console2.log("user USDb balance", userUSDbBalance);

        assertEq(userUSDbBalance, userAssets);
    }

    function testBurnUSDbAndGetUSDe() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        // user gets USDB per normal flow
        vm.startPrank(user);
        usde.approve(address(susde), amount);
        susde.deposit(amount, user);
        susde.approve(address(vault), amount);
        vault.stake(susde.balanceOf(user));

        uint256 userUSDbBalance = usdb.balanceOf(user);
        console2.log("user USDb balance", userUSDbBalance);

        // user burns USDb to get USDe
        redeemer.burn(userUSDbBalance);
        uint256 susdeReceivedBack = susde.balanceOf(user);
        uint256 userUSDeBalance = susde.convertToAssets(susdeReceivedBack);
        console2.log("user USDe balance", userUSDeBalance);

        assertEq(userUSDeBalance, amount);
    }
}
