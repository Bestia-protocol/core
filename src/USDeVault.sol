// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {NonblockingLzApp} from "@layerzerolabs/contracts/lzApp/NonblockingLzApp.sol";
import {IsUSDe} from "./interfaces/IsUSDe.sol";
import {Data} from "./Data.sol";

contract USDeVault is NonblockingLzApp {
    using SafeERC20 for IsUSDe;
    using SafeERC20 for IERC20;

    IsUSDe public immutable susde;
    IERC20 public immutable usde;
    address public immutable usdb;
    address public immutable susdb;
    uint16 public immutable destChainId;

    uint256 public usdbSupply;

    event Stake(address indexed user, uint256 amount);
    event StakeNative(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Rebalanced();

    error RestrictedToRouter();
    error InsufficientAmount();

    constructor(address _lzEndpoint, uint16 _destChainId, address _susde, address _usdb, address _susdb)
        NonblockingLzApp(_lzEndpoint)
    {
        assert(_susde != address(0));
        assert(_usdb != address(0));
        assert(_susdb != address(0));
        destChainId = _destChainId;
        susde = IsUSDe(_susde);
        usde = IERC20(susde.asset());
        usdb = _usdb;
        susdb = _susdb;

        usde.safeApprove(address(susde), type(uint256).max);
    }

    // sUSDe
    function stake(uint256 amount) external payable {
        susde.safeTransferFrom(msg.sender, address(this), amount);

        uint256 amountToMint = susde.convertToAssets(amount);
        Data.Msg memory message = Data.Msg({user: msg.sender, amount: amountToMint, action: Data.Action.MINT});
        bytes memory payload = abi.encode(message);
        _lzSend(destChainId, payload, payable(msg.sender), address(0x0), bytes(""), msg.value);
        usdbSupply += amountToMint;

        emit Stake(msg.sender, amountToMint);
    }

    // USDe
    function stakeNative(uint56 amount) external payable {
        usde.safeTransferFrom(msg.sender, address(this), amount);
        susde.deposit(amount, address(this));

        Data.Msg memory message = Data.Msg({user: msg.sender, amount: amount, action: Data.Action.MINT});
        bytes memory payload = abi.encode(message);
        _lzSend(destChainId, payload, payable(msg.sender), address(0x0), bytes(""), msg.value);
        usdbSupply += amount;

        emit StakeNative(msg.sender, amount);
    }

    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory _payload) internal override {
        (Data.Msg memory payload) = abi.decode(_payload, (Data.Msg));

        assert(payload.action == Data.Action.BURN); // only support redeeming for now

        uint256 toRedeem = susde.convertToShares(payload.amount);
        susde.safeTransfer(payload.user, toRedeem);
        usdbSupply -= payload.amount;

        emit Unstake(payload.user, toRedeem);
    }

    function harvest() external returns (uint256) {
        // TBD
        uint256 toMint;

        // send cross-chain call to mint usdb tokenx
        //bytes memory data = abi.encodeWithSignature("mint(address,uint256)", susdb, toMint);
        //router.call(usdb, data);

        emit Rebalanced();

        return toMint;
    }
}
