// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {OwnerIsCreator} from "@chainlink/contracts@1.4.0/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip@1.6.0/contracts/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip@1.6.0/contracts/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts@1.4.0/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts@1.4.0/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

contract SimpleReceiver is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    error InvalidUsdcToken();
    error InvalidSourceChain();
    error InvalidSenderAddress();
    error NoSenderOnSourceChain(uint64 sourceChainSelector);
    error WrongSenderForSourceChain(uint64 sourceChainSelector);
    error WrongReceivedToken(address usdcToken, address receivedToken);
    error OrderIdNotFound(string orderId);
    error InvalidPaginationParameters();

    event MessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address indexed sender,
        string orderId,
        address token,
        uint256 tokenAmount
    );

    event OrderStored(
        string orderId,
        uint256 amount,
        uint64 sourceChainSelector,
        address sender,
        uint256 timestamp
    );

    struct OrderInfo {
        uint256 amount;
        uint64 sourceChainSelector;
        address sender;
        uint256 timestamp;
        bool exists;
    }

    struct OrderDetails {
        string orderId;
        uint256 amount;
        uint64 sourceChainSelector;
        address sender;
        uint256 timestamp;
    }

    IERC20 private immutable i_usdcToken;
    mapping(uint64 => address) public s_senders;
    mapping(string => OrderInfo) public s_orders;
    string[] public s_orderIds;
    uint256 public s_totalOrders;

    modifier validateSourceChain(uint64 _sourceChainSelector) {
        if (_sourceChainSelector == 0) revert InvalidSourceChain();
        _;
    }

    constructor(
        address _router,
        address _usdcToken
    ) CCIPReceiver(_router) {
        if (_usdcToken == address(0)) revert InvalidUsdcToken();
        i_usdcToken = IERC20(_usdcToken);
    }

    function setSenderForSourceChain(
        uint64 _sourceChainSelector,
        address _sender
    ) external onlyOwner validateSourceChain(_sourceChainSelector) {
        if (_sender == address(0)) revert InvalidSenderAddress();
        s_senders[_sourceChainSelector] = _sender;
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        if (
            abi.decode(any2EvmMessage.sender, (address)) !=
            s_senders[any2EvmMessage.sourceChainSelector]
        ) revert WrongSenderForSourceChain(any2EvmMessage.sourceChainSelector);

        if (any2EvmMessage.destTokenAmounts[0].token != address(i_usdcToken))
            revert WrongReceivedToken(
                address(i_usdcToken),
                any2EvmMessage.destTokenAmounts[0].token
            );

        string memory orderId = abi.decode(any2EvmMessage.data, (string));
        uint256 amount = any2EvmMessage.destTokenAmounts[0].amount;
        address sender = abi.decode(any2EvmMessage.sender, (address));

        // Almacenar la información de la orden
        s_orders[orderId] = OrderInfo({
            amount: amount,
            sourceChainSelector: any2EvmMessage.sourceChainSelector,
            sender: sender,
            timestamp: block.timestamp,
            exists: true
        });

        // Agregar el orderId al array y aumentar el contador
        s_orderIds.push(orderId);
        s_totalOrders++;

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            sender,
            orderId,
            any2EvmMessage.destTokenAmounts[0].token,
            amount
        );

        emit OrderStored(
            orderId,
            amount,
            any2EvmMessage.sourceChainSelector,
            sender,
            block.timestamp
        );
    }

    function getOrderInfo(string memory _orderId) external view returns (OrderInfo memory) {
        OrderInfo memory order = s_orders[_orderId];
        if (!order.exists) revert OrderIdNotFound(_orderId);
        return order;
    }

    function listOrders(uint256 _startIndex, uint256 _endIndex) external view returns (OrderDetails[] memory) {
        if (_startIndex >= _endIndex || _endIndex > s_totalOrders) revert InvalidPaginationParameters();
        
        uint256 length = _endIndex - _startIndex;
        OrderDetails[] memory orders = new OrderDetails[](length);
        
        for (uint256 i = 0; i < length; i++) {
            string memory orderId = s_orderIds[_startIndex + i];
            OrderInfo memory order = s_orders[orderId];
            
            orders[i] = OrderDetails({
                orderId: orderId,
                amount: order.amount,
                sourceChainSelector: order.sourceChainSelector,
                sender: order.sender,
                timestamp: order.timestamp
            });
        }
        
        return orders;
    }

    function getTotalOrders() external view returns (uint256) {
        return s_totalOrders;
    }

    function withdrawUsdcToken(address _beneficiary) public onlyOwner {
        uint256 amount = i_usdcToken.balanceOf(address(this));
        if (amount == 0) revert("No tokens to withdraw");
        i_usdcToken.safeTransfer(_beneficiary, amount);
    }
} 