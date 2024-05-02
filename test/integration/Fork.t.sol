// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Test} from "forge-std/Test.sol";
import {USDb} from "../../src/USDb.sol";
import {USDeVault} from "../../src/USDeVault.sol";
import {StakedUSDb} from "../../src/StakedUSDb.sol";
import {USDeRedeemer} from "../../src/USDeRedeemer.sol";

contract ForkTest is Test {
    address internal constant usde = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address internal constant susde = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address internal constant layerzeroRouter = address(0);
    address internal constant usdeWhale = 0x1c00881a4b935D58E769e7c85F5924B8175D1526;
    address internal constant admin = address(uint160(uint256(keccak256(abi.encodePacked("admin")))));
    address internal constant user = address(uint160(uint256(keccak256(abi.encodePacked("user")))));

    uint256 public immutable mainnetForkId;
    uint256 public immutable arbitrumForkId;
    USDb public immutable usdb;
    StakedUSDb public immutable susdb;
    USDeVault public immutable vault;
    USDeRedeemer public immutable redeemer;

    constructor() {
        mainnetForkId = vm.createFork(vm.envString("MAINNET_FORK_URL"), 19783191);
        arbitrumForkId = vm.createFork(vm.envString("ARBITRUM_FORK_URL"), 207094943);

        vm.selectFork(arbitrumForkId);
        usdb = new USDb(admin);
        susdb = new StakedUSDb(usdb, admin);

        vm.selectFork(mainnetForkId);
        vault = new USDeVault(layerzeroRouter, address(susde), address(usdb), address(susdb));
        vault.setUserStatus(user, true);

        vm.selectFork(arbitrumForkId);
        redeemer = new USDeRedeemer(layerzeroRouter, address(vault), address(usdb));
        redeemer.setUserStatus(user, true);
    }

    function testMintFork() public returns (uint256) {
        vm.selectFork(mainnetForkId);

        IERC20 usdeToken = IERC20(usde);
        IERC4626 susdeToken = IERC4626(susde);
        uint256 balance = usdeToken.balanceOf(usdeWhale);

        vm.prank(usdeWhale);
        usdeToken.transfer(user, balance);

        vm.startPrank(user);
        usdeToken.approve(susde, balance);
        uint256 amount = susdeToken.deposit(balance, user);
        susdeToken.approve(address(vault), amount);
        vault.stake(amount);
        vm.stopPrank();

        // TODO mock LayerZero bridging

        vm.selectFork(arbitrumForkId);
        assertEq(balance, usdb.balanceOf(user));

        return balance;
    }

    function testRedeemFork() public {
        uint256 balance = testMintFork();
        IERC4626 susdeToken = IERC4626(susde);

        vm.selectFork(arbitrumForkId);
        vm.prank(user);
        redeemer.burn(balance);

        // TODO mock LayerZero bridging

        vm.selectFork(mainnetForkId);
        uint256 computedShareBalance = susdeToken.convertToAssets(balance);
        assertEq(computedShareBalance, susdeToken.balanceOf(user));
    }
}
