// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {CCIPReceiver} from "@chainlink-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {USDb} from "./USDb.sol";

contract StakedUSDb is Ownable2Step, ERC20Permit, ERC4626, CCIPReceiver {
    using SafeERC20 for IERC20;

    struct Message {
        address from;
        uint64 localChain;
        uint256 balance;
    }

    uint64 public immutable localChain;
    uint64 public immutable ethenaChain;
    bytes public ethenaContract;
    IRouterClient public immutable router;

    event MessageSent(bytes32 indexed messageId);
    event MessageReceived(bytes32 indexed messageId);
    event TokenSwept(address indexed token, uint256 amount);

    error NonTransferrable();

    constructor(
        uint64 _localChain,
        uint64 _ethenaChain,
        address _ethenaContract,
        address _router,
        address _admin,
        IERC20 _asset
    ) ERC20("Staked USDb", "sUSDb") ERC4626(_asset) ERC20Permit("sUSDb") CCIPReceiver(_router) {
        assert(_admin != address(0));
        _transferOwnership(_admin);

        localChain = _localChain;
        ethenaChain = _ethenaChain;
        ethenaContract = abi.encode(_ethenaContract);
        router = IRouterClient(_router);
    }

    receive() external payable {}

    function decimals() public view virtual override(ERC4626, ERC20) returns (uint8) {
        return ERC4626.decimals();
    }

    function sweep(address token) external onlyOwner {
        assert(token != asset());

        IERC20 spuriousToken = IERC20(token);
        uint256 amount = spuriousToken.balanceOf(address(this));
        spuriousToken.safeTransfer(msg.sender, amount);

        emit TokenSwept(token, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256) internal override {
        if (from != address(0) && to != address(0)) revert NonTransferrable();
    }

    function rebalance() external onlyOwner {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: ethenaContract,
            data: "",
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(0)
        });
        uint256 fee = router.getFee(ethenaChain, message);
        bytes32 messageId = router.ccipSend{value: fee}(ethenaChain, message);

        emit MessageSent(messageId);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        (Message memory receivedMessage) = abi.decode(message.data, (Message));
        USDb token = USDb(asset());
        uint256 usdbBalance = token.balanceOf(address(this));

        if (usdbBalance < receivedMessage.balance) {
            token.mint(address(this), receivedMessage.balance - usdbBalance);
        } else if (usdbBalance > receivedMessage.balance) {
            token.burn(usdbBalance - receivedMessage.balance);
        }

        emit MessageReceived(message.messageId);
    }
}
