// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IsUSDe} from "./interfaces/IsUSDe.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {Whitelisted} from "./Whitelisted.sol";

// temp import for testing, delete before deployment
import {console2} from "forge-std/Test.sol";

// This is the contract you deposit susde into to mint USDb

contract USDeVault is Whitelisted {
    using SafeERC20 for IsUSDe;
    using SafeERC20 for IERC20;
    using Math for uint256;

    IsUSDe public immutable susde;
    address public immutable usdb;
    address public immutable susdb;
    IRouter public immutable router;

    uint256 public susdeSharePrice;
    uint256 public cacheForHarvest;

    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Harvested(uint256 minted);
    event CacheUpdated(uint256 amount);
    event CacheCleared(uint256 amount);

    error RestrictedToRouter();
    error InsufficientAmount();
    error CannotHarvest();

    constructor(address _router, address _susde, address _usdb, address _susdb) Whitelisted(msg.sender) {
        assert(_router != address(0));
        assert(_susde != address(0));
        assert(_usdb != address(0));
        assert(_susdb != address(0));
        router = IRouter(_router);
        susde = IsUSDe(_susde);
        usdb = _usdb;
        susdb = _susdb;

        susdeSharePrice = susde.convertToAssets(1e18);
    }

    // simple stake function to mint USDb with sUSDe deposits
    function stake(uint256 amount) external onlyWhitelisted {
        susde.safeTransferFrom(msg.sender, address(this), amount);

        uint256 amountToMint = susde.convertToAssets(amount);

        // check if the share price has increased and update the cache
        uint256 newSusdeSharePrice = susde.convertToAssets(1e18);
        if (newSusdeSharePrice > susdeSharePrice) {
            updateCache(newSusdeSharePrice);
        }

        // send cross-chain call to mint usdb token
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", msg.sender, amountToMint);
        router.call(usdb, data);

        emit Stake(msg.sender, amountToMint);
    }

    function unstake(address to, uint256 amount) external {
        if (msg.sender != address(router)) revert RestrictedToRouter();

        uint256 amountToRedeem = susde.convertToShares(amount);

        // check if the share price has increased and update the cache
        uint256 newSusdeSharePrice = susde.convertToAssets(1e18);
        if (newSusdeSharePrice > susdeSharePrice) {
            updateCache(newSusdeSharePrice);
        }

        susde.safeTransfer(to, amountToRedeem);

        emit Unstake(msg.sender, amountToRedeem);
    }

    // public function to harvest the yield and mint USDb
    function harvest() public returns (uint256) {
        uint256 newSusdeSharePrice = susde.convertToAssets(1e18);

        // avoid harvesting if the vault has no balance
        if (susde.balanceOf(address(this)) == 0) revert InsufficientAmount();

        // avoid harvesting if the share price is equal or has decreased
        if (newSusdeSharePrice <= susdeSharePrice) revert CannotHarvest();

        // calls the rebalance function to calculate the amount to mint
        uint256 amountToMint = rebalance(newSusdeSharePrice) + cacheForHarvest;

        // update the share price and clear the cache after minting
        susdeSharePrice = newSusdeSharePrice;
        cacheForHarvest = 0;

        // send cross-chain call to mint usdb token
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", susdb, amountToMint);
        router.call(usdb, data);

        emit Harvested(amountToMint);
        emit CacheCleared(cacheForHarvest);

        return amountToMint;
    }

    function rebalance(uint256 _newSusdeSharePrice) internal view returns (uint256) {
        uint256 delta = _newSusdeSharePrice - susdeSharePrice;

        uint256 amountForRebalance = Math.mulDiv(delta, susde.balanceOf(address(this)), 1e18, Math.Rounding.Down);

        return amountForRebalance;
    }

    function updateCache(uint256 _newSusdeSharePrice) internal {
        uint256 tokensForCache = rebalance(_newSusdeSharePrice);
        cacheForHarvest += tokensForCache;
        emit CacheUpdated(tokensForCache);

        susdeSharePrice = _newSusdeSharePrice;
    }
}
