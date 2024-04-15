// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Isusde} from "./interfaces/Isusde.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {Whitelisted} from "./Whitelisted.sol";

// This is the contract you deposit susde into to mint USDb

contract USDeVault is Whitelisted {
    using SafeERC20 for Isusde;
    using SafeERC20 for IERC20;

    Isusde public immutable susde;
    IERC20 public immutable usde;
    address public immutable usdb;
    address public immutable susdb;
    IRouter public immutable router;

    uint256 public susdeSharePrice;

    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Rebalanced(uint256 minted);

    error RestrictedToRouter();
    error InsufficientAmount();
    error CannotHarvest();

    constructor(address _router, address _susde, address _usdb, address _susdb) Whitelisted(msg.sender) {
        assert(_router != address(0));
        assert(_susde != address(0));
        assert(_usdb != address(0));
        assert(_susdb != address(0));
        router = IRouter(_router);
        susde = Isusde(_susde);
        usde = IERC20(susde.asset());
        usdb = _usdb;
        susdb = _susdb;

        susdeSharePrice = susde.convertToAssets(1e18);
    }

    function stake(uint256 amount) external onlyWhitelisted {
        susde.safeTransferFrom(msg.sender, address(this), amount);

        uint256 amountToMint = susde.convertToAssets(amount);
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", msg.sender, amountToMint);
        router.call(usdb, data);

        emit Stake(msg.sender, amountToMint);
    }

    function unstake(address to, uint256 amount) external {
        if (msg.sender != address(router)) revert RestrictedToRouter();

        uint256 amountToRedeem = susde.convertToShares(amount);
        susde.safeTransfer(to, amountToRedeem);

        emit Unstake(msg.sender, amountToRedeem);
    }

    function harvest() external returns (uint256) {
        uint256 newSusdeSharePrice = susde.convertToAssets(1e18);

        // avoid harvesting if the share price is equal or has decreased
        if (newSusdeSharePrice <= susdeSharePrice) revert CannotHarvest();
        uint256 amountToMint = (newSusdeSharePrice - susdeSharePrice) * susde.balanceOf(address(this));

        // send cross-chain call to mint usdb tokenx
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", susdb, amountToMint);
        router.call(usdb, data);
        susdeSharePrice = newSusdeSharePrice;

        emit Rebalanced(amountToMint);

        return amountToMint;
    }
}
