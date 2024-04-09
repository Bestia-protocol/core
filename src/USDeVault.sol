// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IsUSDe} from "./interfaces/IsUSDe.sol";
import {IRouter} from "./interfaces/IRouter.sol";

contract USDeVault {
    using SafeERC20 for IsUSDe;
    using SafeERC20 for IERC20;

    IsUSDe public immutable susde;
    IERC20 public immutable usde;
    address public immutable usdb;
    address public immutable susdb;
    IRouter public immutable router;

    uint256 public usdbSupply;

    event Stake(address indexed user, uint256 amount);
    event StakeNative(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Rebalanced();

    error RestrictedToRouter();
    error InsufficientAmount();

    constructor(address _router, address _susde, address _usdb, address _susdb) {
        assert(_router != address(0));
        assert(_susde != address(0));
        assert(_usdb != address(0));
        assert(_susdb != address(0));
        router = IRouter(_router);
        susde = IsUSDe(_susde);
        usde = IERC20(susde.asset());
        usdb = _usdb;
        susdb = _susdb;
    }

    receive() external payable {}

    // sUSDe
    function stake(uint256 amount) external {
        susde.safeTransferFrom(msg.sender, address(this), amount);

        uint256 amountToMint = susde.convertToAssets(amount);
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", msg.sender, amountToMint);
        router.call(usdb, data);
        usdbSupply += amountToMint;

        emit Stake(msg.sender, amountToMint);
    }

    function stakeNative(uint56 amount) external {
        usde.safeTransferFrom(msg.sender, address(this), amount);

        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", msg.sender, amount);
        router.call(usdb, data);
        usdbSupply += amount;

        emit StakeNative(msg.sender, amount);
    }

    function unstake(address to, uint256 amount) external {
        if (msg.sender != address(router)) revert RestrictedToRouter();

        uint256 toRedeem = susde.convertToShares(amount);
        susde.safeTransfer(to, toRedeem);
        usdbSupply -= amount;

        emit Unstake(msg.sender, toRedeem);
    }

    function harvest() external returns (uint256) {
        // TBD
        uint256 toMint;

        // send cross-chain call to mint usdb tokenx
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", susdb, toMint);
        router.call(usdb, data);

        emit Rebalanced();

        return toMint;
    }
}
