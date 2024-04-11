// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

library Data {
    enum Action {
        MINT,
        BURN
    }

    struct Msg {
        address user;
        uint256 amount;
        Action action;
    }
}
