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

    // simple stake function to mint USDb with sUSDe deposits
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

    // function to stake and rebalance the interest earned on sUSDb deposits
    function stakeAndHarvest(uint256 amount) external onlyWhitelisted {
        // first create the additional USDb to mint based on sUSDe deposits
        uint256 rebalanceAmount = rebalance();
        // then calculate the amount of USDb to mint based on the incoming sUSDe deposit
        uint256 amountToMint = susde.convertToAssets(amount);

        susde.safeTransferFrom(msg.sender, address(this), amount);

        bytes memory data = abi.encodeWithSignature(
            "mintAndRebalance(address,uint256,address,uint256)",
            msg.sender,
            amountToMint,
            address(susdb),
            rebalanceAmount
        );

        router.call(usdb, data);
    }

    function unstake(address to, uint256 amount) external {
        if (msg.sender != address(router)) revert RestrictedToRouter();

        uint256 amountToRedeem = susde.convertToShares(amount);
        uint256 exitInterest = exitRebalance(amount);
        
        susde.safeTransfer(to, amountToRedeem + exitInterest);

        emit Unstake(msg.sender, amountToRedeem + exitInterest);
    }

    // public function to harvest the yield and mint USDb
    function harvest() public returns (uint256) {
        uint256 newSusdeSharePrice = susde.convertToAssets(1e18);

        // avoid harvesting if the share price is equal or has decreased
        if (newSusdeSharePrice <= susdeSharePrice) revert CannotHarvest();

        // calls the rebalance function to calculate the amount to mint
        uint256 amountToMint = rebalance();

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

    function rebalance() internal view returns (uint256) {
        uint256 newSusdeSharePrice = susde.convertToAssets(1e18);

        // Execute rebalancing only if the share price has increased
        if (newSusdeSharePrice > susdeSharePrice) {
            uint256 delta = newSusdeSharePrice - susdeSharePrice;

            uint256 amountToMint = Math.mulDiv(
                delta,
                susde.balanceOf(address(this)),
                1e18
            );

            return amountToMint;
        }

        return 0; // Return zero if no rebalancing required
    }

    // calculates any additional sUSDe to return to user based on the current share price vs the share price at last harvest
    function exitRebalance(uint256 amount) internal view returns (uint256) {
        uint256 newSusdeSharePrice = susde.convertToAssets(1e18);

        if (newSusdeSharePrice > susdeSharePrice) {
            uint256 delta = newSusdeSharePrice - susdeSharePrice;

            uint256 exitInterest = Math.mulDiv(
                delta,
                susde.convertToShares(amount),
                1e18
            );

            return exitInterest;
        }
        return 0; // Return zero if no exit interest due
    }
}
