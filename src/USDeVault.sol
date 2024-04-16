// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Isusde} from "./interfaces/Isusde.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {Whitelisted} from "./Whitelisted.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// temp import for testing, delete before deployment
import {console2} from "forge-std/Test.sol";

// This is the contract you deposit susde into to mint USDb

contract USDeVault is Whitelisted {
    using SafeERC20 for Isusde;
    using SafeERC20 for IERC20;
    using Math for uint256;

    Isusde public immutable susde;
    IERC20 public immutable usde;
    address public immutable usdb;
    address public immutable susdb;
    IRouter public immutable router;

    uint256 public susdeSharePrice;

    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Harvested(uint256 minted);
    event Rebalanced(uint256 minted);

    error RestrictedToRouter();
    error InsufficientAmount();
    error CannotHarvest();

    constructor(
        address _router,
        address _susde,
        address _usdb,
        address _susdb
    ) Whitelisted(msg.sender) {
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
        bytes memory data = abi.encodeWithSignature(
            "mint(address,uint256)",
            msg.sender,
            amountToMint
        );
        router.call(usdb, data);

        emit Stake(msg.sender, amountToMint);
    }

    function stakeAndRebalance(uint256 amount) external onlyWhitelisted {
        susde.safeTransferFrom(msg.sender, address(this), amount);

        uint256 amountToMint = susde.convertToAssets(amount);
        uint256 rebalanceAmount = rebalance();

        bytes memory data = abi.encodeWithSignature(
            "mintAndRebalance(address,uint256,address,uint256)",
            msg.sender,
            amountToMint,
            address(this),
            rebalanceAmount
        );

        router.call(usdb, data);
    }

    function unstake(address to, uint256 amount) external {
        if (msg.sender != address(router)) revert RestrictedToRouter();

        uint256 amountToRedeem = susde.convertToShares(amount);
        susde.safeTransfer(to, amountToRedeem);

        emit Unstake(msg.sender, amountToRedeem);
    }

    function harvest() public returns (uint256) {
        uint256 newSusdeSharePrice = susde.convertToAssets(1e18);

        // avoid harvesting if the share price is equal or has decreased
        if (newSusdeSharePrice <= susdeSharePrice) revert CannotHarvest();
        uint256 delta = newSusdeSharePrice - susdeSharePrice;

        uint256 amountToMint = Math.mulDiv(
            delta,
            susde.balanceOf(address(this)),
            1e18
        );

        // send cross-chain call to mint usdb token
        bytes memory data = abi.encodeWithSignature(
            "mint(address,uint256)",
            susdb,
            amountToMint
        );
        router.call(usdb, data);
        susdeSharePrice = newSusdeSharePrice;

        emit Harvested(amountToMint);

        return amountToMint;
    }

    function rebalance() internal returns (uint256) {
        uint256 newSusdeSharePrice = susde.convertToAssets(1e18);

        // Execute rebalancing only if the share price has increased
        if (newSusdeSharePrice > susdeSharePrice) {
            uint256 amountToMint = (newSusdeSharePrice - susdeSharePrice) *
                susde.balanceOf(address(this));
            susdeSharePrice = newSusdeSharePrice;
            return amountToMint;
        }

        return 0; // Return zero if no rebalancing occurred
    }
}
