// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IRouter} from "./interfaces/IRouter.sol";
import {USDb} from "./USDb.sol";
import {Whitelisted} from "./Whitelisted.sol";

contract USDeRedeemer is Whitelisted {
    address public immutable vault; //< this may be upgradable
    IRouter public immutable router;
    USDb public immutable usdb;

    constructor(address _router, address _vault, address _usdb) Whitelisted(msg.sender) {
        assert(_vault != address(0));
        assert(_router != address(0));
        vault = _vault;
        router = IRouter(_router);
        usdb = USDb(_usdb);
    }

    function burn(uint256 amount) external onlyWhitelisted {
        usdb.burn(msg.sender, amount);
        // send cross-chain call to vault
        bytes memory data = abi.encodeWithSignature("unstake(address,uint256)", msg.sender, amount);
        router.call(vault, data);
    }
}
