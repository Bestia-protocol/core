// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

// Mock Router for testing

contract CrossChainRouter {
    function call(address destination, bytes memory data) external {
        (bool success,) = destination.call(data);
        assert(success);
    }
}
