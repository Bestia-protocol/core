// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

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
    uint256 public protocolReserve;
    uint256 public harvestingFee;

    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Harvested(uint256 minted);
    event CacheUpdated(uint256 amount, uint256 oldSusdeSharePrice, uint256 newSusdeSharePrice);
    event CacheCleared(uint256 amount);
    event HarvestingFeeUpdated(uint256 oldFee, uint256 newFee);
    event DepositedToReserve(uint256 amount, uint256 newReserveBalance);
    event WithdrawFromReserve(uint256 amount, uint256 newReserveBalance);

    error InsufficientReserveBalance();
    error InsufficientFreeLiquidity();
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
        protocolReserve = 0;
        harvestingFee = 0;

        susdeSharePrice = susde.convertToAssets(1e18);
    }

    function setHarvestingFee(uint256 newHarvestingFee) external onlyOwner {
        emit HarvestingFeeUpdated(harvestingFee, newHarvestingFee);

        harvestingFee = newHarvestingFee;
    }

    function depositToReserve(uint256 amount) external onlyOwner {
        susde.safeTransferFrom(msg.sender, address(this), amount);

        protocolReserve += amount;

        emit DepositedToReserve(amount, protocolReserve);
    }

    function withdrawFromReserve(uint256 amount) external onlyOwner {
        if (protocolReserve < amount) revert InsufficientReserveBalance();
        if (susde.balanceOf(address(this)) < amount) revert InsufficientFreeLiquidity();

        protocolReserve -= amount;

        susde.safeTransfer(msg.sender, amount);

        emit WithdrawFromReserve(amount, protocolReserve);
    }

    // simple stake function to mint USDb with sUSDe deposits
    function stake(uint256 amount) external onlyWhitelisted {
        susde.safeTransferFrom(msg.sender, address(this), amount);

        // check if the share price has increased and update the cache
        uint256 newSusdeSharePrice = _getSharePrice();
        if (newSusdeSharePrice > susdeSharePrice) {
            _updateCache(newSusdeSharePrice);
        }

        uint256 amountToMint = amount * susdeSharePrice;

        // send cross-chain call to mint usdb token
        bytes memory data = abi.encodeWithSignature("mint(address,uint256)", msg.sender, amountToMint);
        router.call(usdb, data);

        emit Stake(msg.sender, amountToMint);
    }

    function unstake(address to, uint256 amount) external {
        if (msg.sender != address(router)) revert RestrictedToRouter();

        // check if the share price has increased and update the cache
        uint256 newSusdeSharePrice = _getSharePrice();
        if (newSusdeSharePrice > susdeSharePrice) {
            _updateCache(newSusdeSharePrice);
        }

        uint256 amountToRedeem = amount / newSusdeSharePrice;
        if (susde.balanceOf(address(this)) < amountToRedeem) revert InsufficientFreeLiquidity();

        susde.safeTransfer(to, amountToRedeem);

        emit Unstake(msg.sender, amountToRedeem);
    }

    // public function to harvest the yield and mint USDb
    function harvest() public returns (uint256) {
        uint256 newSusdeSharePrice = _getSharePrice();

        // avoid harvesting if the vault has no balance
        if (susde.balanceOf(address(this)) == 0) revert InsufficientAmount();

        // avoid harvesting if the share price is equal or has decreased
        if (newSusdeSharePrice <= susdeSharePrice) revert CannotHarvest();

        // calls the _rebalance function to calculate the amount to mint
        uint256 amountToMint = _rebalance(newSusdeSharePrice) + cacheForHarvest;

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

    function _rebalance(uint256 newSusdeSharePrice) internal view returns (uint256) {
        uint256 delta = newSusdeSharePrice - susdeSharePrice;

        uint256 amountToRebalance = Math.mulDiv(delta, susde.balanceOf(address(this)), 1e18, Math.Rounding.Down);

        return amountToRebalance;
    }

    function _updateCache(uint256 newSusdeSharePrice) internal {
        uint256 tokensForCache = _rebalance(newSusdeSharePrice);
        uint256 protocolShare = cacheForHarvest * harvestingFee;
        cacheForHarvest += tokensForCache - protocolShare;
        protocolReserve += protocolShare;

        emit CacheUpdated(tokensForCache, susdeSharePrice, newSusdeSharePrice);

        susdeSharePrice = newSusdeSharePrice;
    }

    function _getSharePrice() internal view returns (uint256) {
        uint256 price = susde.convertToAssets(1e18);
        if (price < susdeSharePrice) return susdeSharePrice;
        return price;
    }
}
