// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleUSDCStorage is Ownable {
    using SafeERC20 for IERC20;

    error InvalidUsdcToken();
    error InvalidAmount();
    error OrderIdNotFound(string orderId);
    error InvalidPaginationParameters();
    error NoTokensToWithdraw();
    error OrderIdAlreadyExists(string orderId);
    error InsufficientUsdcBalance(uint256 required, uint256 available);
    error InsufficientUsdcAllowance(uint256 required, uint256 available);

    event OrderStored(
        string orderId,
        uint256 amount,
        address sender,
        uint256 timestamp
    );

    struct OrderInfo {
        uint256 amount;
        address sender;
        uint256 timestamp;
        bool exists;
    }

    struct OrderDetails {
        string orderId;
        uint256 amount;
        address sender;
        uint256 timestamp;
    }

    IERC20 private immutable i_usdcToken;
    mapping(string => OrderInfo) public s_orders;
    string[] public s_orderIds;
    uint256 public s_totalOrders;

    constructor(address _usdcToken) Ownable(msg.sender) {
        if (_usdcToken == address(0)) revert InvalidUsdcToken();
        i_usdcToken = IERC20(_usdcToken);
    }

    function storeOrder(
        string memory _orderId,
        uint256 _amount
    ) external {
        if (_amount == 0) revert InvalidAmount();
        if (s_orders[_orderId].exists) revert OrderIdAlreadyExists(_orderId);

        // Verificar balance de USDC
        uint256 usdcBalance = i_usdcToken.balanceOf(msg.sender);
        if (usdcBalance < _amount) revert InsufficientUsdcBalance(_amount, usdcBalance);

        // Verificar allowance de USDC
        uint256 usdcAllowance = i_usdcToken.allowance(msg.sender, address(this));
        if (usdcAllowance < _amount) revert InsufficientUsdcAllowance(_amount, usdcAllowance);

        // Transferir USDC al contrato
        i_usdcToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Almacenar la información de la orden
        s_orders[_orderId] = OrderInfo({
            amount: _amount,
            sender: msg.sender,
            timestamp: block.timestamp,
            exists: true
        });

        // Agregar el orderId al array y aumentar el contador
        s_orderIds.push(_orderId);
        s_totalOrders++;

        emit OrderStored(
            _orderId,
            _amount,
            msg.sender,
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
                sender: order.sender,
                timestamp: order.timestamp
            });
        }
        
        return orders;
    }

    function getTotalOrders() external view returns (uint256) {
        return s_totalOrders;
    }

    function withdrawUsdcToken(address _beneficiary) external onlyOwner {
        uint256 amount = i_usdcToken.balanceOf(address(this));
        if (amount == 0) revert NoTokensToWithdraw();
        i_usdcToken.safeTransfer(_beneficiary, amount);
    }

    function getUsdcBalance() external view returns (uint256) {
        return i_usdcToken.balanceOf(address(this));
    }

} 
