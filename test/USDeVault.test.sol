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
    Mock4626Vault internal immutable sUSDeV2;
    USDb public immutable usdb;
    CrossChainRouter public immutable router;
    USDeVault public immutable vault;
    USDeRedeemer public immutable redeemer;

    constructor() {
        usde = new MockUSDe(); // Mock USDe
        sUSDeV2 = new Mock4626Vault(usde); // Mock StakedUSDeV2
        usdb = new USDb(address(this));
        router = new CrossChainRouter();
        vault = new USDeVault(
            address(router),
            address(usde),
            address(sUSDeV2),
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
        usde.approve(address(sUSDeV2), amount);
        sUSDeV2.deposit(amount, user);
        vm.stopPrank();

        console2.log("balanceOf", sUSDeV2.balanceOf(user));
        console2.log("totalSupply", sUSDeV2.totalSupply());

        assertEq(sUSDeV2.balanceOf(user), amount);
    }    
}
