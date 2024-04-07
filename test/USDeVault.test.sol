// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ERC20PresetMinterPauser} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {USDb} from "../src/USDb.sol";
import {USDeVault} from "../src/USDeVault.sol";
import {USDeRedeemer} from "../src/USDeRedeemer.sol";
import {CrossChainRouter} from "../src/CrossChainRouter.sol";

contract USDeVaultTest is Test {
    address internal constant sink = address(0x1);
    address internal constant user = address(0x2);
    ERC20PresetMinterPauser internal immutable usde;
    USDb internal immutable usdb;
    CrossChainRouter internal immutable router;
    USDeVault internal immutable vault;
    USDeRedeemer internal immutable redeemer;

    constructor() {
        usde = new ERC20PresetMinterPauser("USDe", "USDe");
        usdb = new USDb(address(this));
        router = new CrossChainRouter();
        vault = new USDeVault(address(router), address(usde), address(usdb), sink);
        redeemer = new USDeRedeemer(address(router), address(vault), address(usdb));
    }

    function setUp() public {
        usdb.addMinter(address(router));
        usdb.addMinter(address(redeemer));
        vm.prank(user);
        usde.approve(address(vault), type(uint256).max);
    }

    function testMintUSDbByStakingUSDe() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);
        vm.prank(user);
        vault.stake(amount);

        assertEq(usdb.balanceOf(user), amount);
    }

    function testBurnUSDbAndGetUSDe() external {
        uint256 amount = 1e18;
        usde.mint(user, amount);

        vm.startPrank(user);
        vault.stake(amount);
        redeemer.burn(amount);
        vm.stopPrank();

        assertEq(usdb.balanceOf(user), 0);
        assertEq(usde.balanceOf(user), amount);
    }
}
