// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IRouter} from "./interfaces/IRouter.sol";

contract USDeRedeemer {
    address public immutable vault; //< this may be upgradable
    IRouter public immutable router;

    constructor(address _vault, address _router) {
        assert(_vault != address(0));
        assert(_router != address(0));
        vault = _vault;
        router = IRouter(_router);
    }

    function burn(uint256 amount) external {
        // send cross-chain call to vault

        bytes memory data = abi.encodeWithSignature("unstake(address,uint256)", msg.sender, amount);
        router.call(vault, data);
    }
}
