// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {TestSetup} from "../TestSetup.t.sol";
import {console2} from "forge-std/Test.sol";

contract ExitRebalanceTest is TestSetup {
    uint256 susdeStartingBalance = 0; // large initial balance for the vault
    uint256 amount = 1e18; // deposit amount of 1 USDe
    uint256 yield = 1e16; // 1% yield
    uint256 maxRoundingError = 5;

    // test a more complex interaction where multiple users stake usdb and withdraw
    // first do with no other susde holders
    // second do with a large initial balance for the susde vault

    function testProfitsStayInSync() public {
        // fund users with USDe
        fundUsers();

        // large initial balance for the vault
        vm.startPrank(user);
        susde.deposit(susdeStartingBalance, user);        
        vm.stopPrank();

        // user2 deposits USDe to sUSDe vault and stakes to get sUSDb
        setupUserAsSusdbStaker(user2);
                
        // mint 1e16 USDe to sUSDe vault to simulate yield
        usde.mint(address(susde), yield);        

        // add user3
        setupUserAsSusdbStaker(user3);

        // mint 1e16 USDe to sUSDe vault to simulate yield
        usde.mint(address(susde), yield);

        vault.harvest();

        assertEq(
            usdb.balanceOf(address(susdb)),
            susde.convertToAssets(susde.balanceOf(address(vault)))
        );
    }

    function getVaultUSDeBalance() public view returns (uint256) {
        return susde.convertToAssets(susde.balanceOf(address(vault)));
    }

    function setupUserAsSusdbStaker(address _user) public {
        vm.startPrank(_user);
        susde.deposit(amount, _user);
        vault.stakeAndHarvest(susde.balanceOf(_user));
        susdb.deposit(usdb.balanceOf(_user), _user);
        vm.stopPrank();
    }

    function fundUsers() public {
        usde.mint(user, susdeStartingBalance);
        usde.mint(user, amount);
        usde.mint(user2, amount);
        usde.mint(user3, amount);
        usde.mint(user4, amount);
    }
}
