// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {MockUSDe} from "./mock/MockUSDe.sol";
import {Mock4626Vault} from "./mock/Mock4626Vault.sol";
import {USDb} from "../src/USDb.sol";
import {USDeVault} from "../src/USDeVault.sol";
import {USDeRedeemer} from "../src/USDeRedeemer.sol";
import {CrossChainRouter} from "../src/CrossChainRouter.sol";

contract USDeVaultTest is Test {
    address public constant sink = address(0x1);
    address public constant user = address(0x2);
    MockUSDe public immutable usde;
    Mock4626Vault internal immutable susde;
    USDb public immutable usdb;
    CrossChainRouter public immutable router;
    USDeVault public immutable vault;
    USDeRedeemer public immutable redeemer;

    constructor() {
        usde = new MockUSDe(); // Mock USDe
        susde = new Mock4626Vault(usde); // Mock StakedUSDeV2
        usdb = new USDb(address(this));
        router = new CrossChainRouter();
        vault = new USDeVault(
            address(router),
            address(usde),
            address(susde),
            address(usdb),
            sink
        );
        redeemer = new USDeRedeemer(
            address(router),
            address(vault),
            address(usdb)
        );
    }

    function setUp() public {
        usdb.addMinter(address(router));
        usdb.addMinter(address(redeemer));
        vm.prank(user);
        usde.approve(address(vault), type(uint256).max);
    }

    function testBasic4626VaultFunctions() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        vm.startPrank(user);
        usde.approve(address(susde), amount);
        susde.deposit(amount, user);
        vm.stopPrank();

        console2.log("balanceOf", susde.balanceOf(user));
        console2.log("totalSupply", susde.totalSupply());
        console2.log("asset of susde", susde.asset());

        assertEq(susde.balanceOf(user), amount);
        assertEq(susde.asset(), address(usde));
    }

    function testTotalAssets() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        vm.startPrank(user);
        usde.approve(address(susde), amount);
        susde.deposit(amount, user);
        vm.stopPrank();

        // mint additional USDe to susde
        usde.mint(address(susde), amount);

        console2.log("total USDe in susde", usde.balanceOf(address(susde)));
        console2.log("totalAssets of susde", susde.totalAssets());

        // asserts that assets in susde accounts for deposits as well as additional USDe minted to susde
        assertEq(usde.balanceOf(address(susde)), amount * 2);
    }

    function testConvertToAssets() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        vm.startPrank(user);
        usde.approve(address(susde), amount);
        susde.deposit(amount, user);
        vm.stopPrank();

        uint256 shares = susde.balanceOf(user);
        console2.log(
            "convertToAssets user balance before",
            susde.convertToAssets(shares)
        );

        // mint additional USDe to susde
        usde.mint(address(susde), amount);

        console2.log(
            "convertToAssets user balance after",
            susde.convertToAssets(shares)
        );

        console2.log("previewRedeem", susde.previewRedeem(shares));

       // assert that convertToAssets correctly calculate the USDe owed to user
       uint256 expectedAssets = amount * 2;
       uint256 actualAssets = susde.convertToAssets(shares);
       uint256 tolerance = 1;
       
       // assertion with tolerance due to OZ ERC4626 rounding down
       assertApproxEqAbs(expectedAssets, actualAssets, tolerance);
    }
}
