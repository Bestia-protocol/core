// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {console2} from "forge-std/Test.sol";
import {TestSetup} from "../TestSetup.t.sol";
import {USDeVault} from "../../src/USDeVault.sol";

contract USDeVaultTest is TestSetup {
    function testMintUSDbByStakingUSDe(uint256 amount) external {
        vm.assume(amount < type(uint256).max);

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

    function testUSDBMintingWithInterest(uint128 amount, uint128 profits) external {
        usde.mint(user, amount);

        // user deposts USDe to sUSDe vault
        vm.startPrank(user);
        susde.deposit(amount, user);
        vm.stopPrank();

        // more USDe is minted to sUSDe to simulate interest earned
        usde.mint(address(susde), profits);

        uint256 userShares = susde.balanceOf(user);
        uint256 userAssets = susde.convertToAssets(userShares);

        vm.startPrank(user);
        vault.stake(susde.balanceOf(user));
        vm.stopPrank();

        uint256 userUSDbBalance = usdb.balanceOf(user);

        assertEq(userUSDbBalance, userAssets);
    }

    function testBurnUSDbAndGetUSDe(uint256 amount) external {
        vm.assume(amount < type(uint256).max);

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
        uint256 interestEarnedInUSDe = susde.convertToAssets(susde.balanceOf(address(vault))) - amount;

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
        uint256 interestEarnedInUSDe = susde.convertToAssets(susde.balanceOf(address(vault))) - amount;

        // harvest the interest to mint USDb to staked USDb vault
        vault.harvest();

        // check the USDb minted by the harvest function
        uint256 usdbMintedByHarvest1 = usdb.balanceOf(address(susdb));

        // simulate another 100% profit and harvest to send to staked USDb vault
        usde.mint(address(susde), amount);
        vault.harvest();

        // check the USDb minted by the harvest function
        uint256 usdbMintedByHarvest2 = usdb.balanceOf(address(susdb)) - usdbMintedByHarvest1;

        assertEq(usdbMintedByHarvest1 + usdbMintedByHarvest2, interestEarnedInUSDe * 2);
    }

    // test a cache is updated when USDb is minted is deposited to the vault
    function testCacheOnDeposit() external {
        uint256 amount = 1e18;
        uint256 roundingError = 5; // max rounding error of 5
        usde.mint(user, amount);
        usde.mint(user2, amount);

        // user deposits USDe to sUSDe vault, and then stakes to get USDb
        vm.startPrank(user);
        susde.deposit(amount, user);
        vault.stake(amount);
        susdb.deposit(usdb.balanceOf(user), user);
        vm.stopPrank();

        console2.log("cacheForHarvest before mint ", vault.cacheForHarvest());

        // simulate 100% profit but no harvest called
        usde.mint(address(susde), amount);

        console2.log("cacheForHarvest after mint ", vault.cacheForHarvest());

        console2.log("total assets in susde after mint ", susde.convertToAssets(susde.totalSupply()));
        console2.log("total assets in vault after mint ", susde.convertToAssets(susde.balanceOf(address(vault))));

        // check interest earned by the vault's position in USDe terms by subtracting the initial amount
        uint256 interestEarnedInUSDe = susde.convertToAssets(susde.balanceOf(address(vault))) - amount;

        console2.log("interestEarnedInUSDe ", interestEarnedInUSDe);

        vm.startPrank(user2);
        susde.deposit(amount, user2);
        vault.stake(susdb.balanceOf(user2));
        susdb.deposit(usdb.balanceOf(user2), user2);
        vm.stopPrank();

        // user unstakes and withdraws to USDe
        vm.startPrank(user);
        susdb.redeem(susdb.balanceOf(user), user, user);
        redeemer.burn(usdb.balanceOf(user));
        susde.redeem(susde.balanceOf(user), user, user);
        vm.stopPrank();

        // check balance in the cache
        uint256 cacheAfterDeposit = vault.cacheForHarvest();
        console2.log("cacheAfterDeposit ", cacheAfterDeposit);

        // assert that the cache is updated with the interest earned
        assertApproxEqAbs(cacheAfterDeposit, interestEarnedInUSDe, roundingError);
    }

    function testProtocolReserve() external {
        uint256 amount = 100 * 1e18;
        usde.mint(user, amount);

        vm.startPrank(user);
        susde.deposit(amount, user);
        vault.stake(amount);
        vm.stopPrank();

        // increase protocol reserve
        usde.approve(address(susde), type(uint256).max);
        susde.approve(address(vault), type(uint256).max);
        usde.mint(address(this), amount);
        susde.deposit(amount, address(this));
        vault.depositToReserve(amount);

        // simulate sUSDe share price decrease
        vm.prank(address(susde));
        usde.burn(1e18);

        vm.prank(user);
        redeemer.burn(amount);

        // check that user got out more sUSDe than what was staked
        assertGt(susde.balanceOf(user), amount);

        vm.expectRevert(USDeVault.InsufficientFreeLiquidity.selector);
        vault.withdrawFromReserve(amount);
    }
}
