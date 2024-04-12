// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract Whitelisted is Ownable2Step {
    mapping(address user => bool allowed) public whitelisted;

    event UserStatusChanged(address indexed user, bool previousStatus, bool newStatus);

    error RestrictedToWhitelistedUsers();

    constructor(address admin) {
        assert(admin != address(0));
        _transferOwnership(admin);
    }

    modifier onlyWhitelisted() {
        if (!whitelisted[msg.sender]) revert RestrictedToWhitelistedUsers();
        _;
    }

    function setUserStatus(address user, bool status) external onlyOwner {
        emit UserStatusChanged(user, whitelisted[user], status);
        whitelisted[user] = status;
    }
}
