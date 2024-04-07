// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IRouter {
    function call(address destination, bytes memory data) external;
}
