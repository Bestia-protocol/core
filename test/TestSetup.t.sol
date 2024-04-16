// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {MockUSDe} from "./mock/MockUSDe.sol";
import {Mock4626Vault} from "./mock/Mock4626Vault.sol";
import {USDb} from "../src/USDb.sol";
import {USDeVault} from "../src/USDeVault.sol";
import {StakedUSDb} from "../src/StakedUSDb.sol";
import {USDeRedeemer} from "../src/USDeRedeemer.sol";
import {CrossChainRouter} from "../src/CrossChainRouter.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract TestSetup is Test {
    address public constant sink = address(0x1);
    address public constant user = address(0x2);
    MockUSDe public immutable usde;
    Mock4626Vault internal immutable susde;
    USDb public immutable usdb;
    CrossChainRouter public immutable router;
    USDeVault public immutable vault;
    USDeRedeemer public immutable redeemer;
    StakedUSDb public immutable susdb;

    constructor() {
        usde = new MockUSDe(); // Mock USDe
        susde = new Mock4626Vault(address(usde)); // Mock StakedUSDeV2
        usdb = new USDb(address(this));
        router = new CrossChainRouter();
        vault = new USDeVault(
            address(router),
            address(susde),
            address(usdb),
            sink
        );
        redeemer = new USDeRedeemer(
            address(router),
            address(vault),
            address(usdb)
        );
        susdb = new StakedUSDb(usdb, address(this));

        vault.setUserStatus(user, true);
        redeemer.setUserStatus(user, true);
    }

    function setUp() public {
        usdb.addMinter(address(router));
        usdb.addMinter(address(redeemer));
        vm.prank(user);
        usde.approve(address(vault), type(uint256).max);

        vm.startPrank(user);
        susde.approve(address(vault), type(uint256).max);
        usde.approve(address(susde), type(uint256).max);
        vm.stopPrank();
    }
}
