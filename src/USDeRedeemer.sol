// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {NonblockingLzApp} from "@layerzerolabs/contracts/lzApp/NonblockingLzApp.sol";
import {USDb} from "./USDb.sol";
import {Data} from "./Data.sol";

/**
 * @dev allows USDe holders on Sei to burn their tokens and
 *      get the corresponding amount of sUSDe on Ethereum mainnet
 */
contract USDeRedeemer is NonblockingLzApp {
    address public immutable vault;
    /// TODO this may be upgradable
    USDb public immutable usdb;
    uint16 public immutable destChainId;

    error NotImplemented();

    constructor(address _lzEndpoint, uint16 _destChainId, address _vault, address _usdb)
        NonblockingLzApp(_lzEndpoint)
    {
        assert(_vault != address(0));
        destChainId = _destChainId;
        vault = _vault;
        usdb = USDb(_usdb); // this contract must be an authorised minter
    }

    function burn(uint256 amount) external payable {
        usdb.burn(msg.sender, amount);
        // send cross-chain call to vault
        Data.Msg memory message = Data.Msg({user: msg.sender, amount: amount, action: Data.Action.BURN});
        bytes memory payload = abi.encode(message);
        _lzSend(destChainId, payload, payable(msg.sender), address(0x0), bytes(""), msg.value);
    }

    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory) internal override {
        revert NotImplemented();
    }
}
