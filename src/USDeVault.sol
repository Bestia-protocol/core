// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUSDe} from "./interfaces/IUSDe.sol";
import {IRouter} from "./interfaces/IRouter.sol";

contract USDeVault {
    using SafeERC20 for IUSDe;

    IUSDe public immutable usde;
    IRouter public immutable router;
    address public immutable usdb;
    address public immutable susdb; //< this may be upgradable
    mapping(address => uint256) public stakes;

    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Rebalanced();

    error RestrictedToRouter();
    error InsufficientAmount();

    constructor(address _router, address _usde, address _usdb, address _susdb) {
        assert(_usde != address(0));
        assert(_router != address(0));
        usde = IUSDe(_usde);
        router = IRouter(_router);
        usdb = _usdb;
        susdb = _susdb;
    }

    receive() external payable {}

    function stake(uint256 amount) external {
        usde.safeTransferFrom(msg.sender, address(this), amount);
        stakes[msg.sender] += amount;

        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", msg.sender, amount);
        router.call(usdb, data);

        emit Stake(msg.sender, amount);
    }

    // can only unstake by burning usdb on Sei
    function unstake(address to, uint256 amount) external {
        if (msg.sender != address(router)) revert RestrictedToRouter();

        if (amount > stakes[to]) revert InsufficientAmount();
        stakes[to] -= amount;
        usde.safeTransfer(to, amount);

        emit Unstake(msg.sender, amount);
    }

    function harvest() external returns (uint256) {
        uint256 balanceBefore = usde.balanceOf(address(this));
        usde.unstake(msg.sender);
        uint256 balanceAfter = usde.balanceOf(address(this));
        assert(balanceAfter > balanceBefore); // avoid rebalancing if no gains matured
        uint256 toMint = balanceAfter - balanceBefore;
        usde.deposit(usde.balanceOf(address(this)), address(this));
        // send cross-chain call to mint usdb tokenx

        // mint to the sUSBb staking vault the excess (s)USDe collected
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", susdb, toMint);
        router.call(usdb, data);

        emit Rebalanced();

        return toMint;
    }
}
