// (c) 2023, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

// SPDX-License-Identifier: Ecosystem

pragma solidity ^0.8.18;

import "@teleporter/ITeleporterMessenger.sol";
import "@teleporter/ITeleporterReceiver.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Contrato del token que se minteará
contract SimpleToken is ERC20 {
    constructor() ERC20("SimpleToken", "STK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SimpleReceiverOnPrivado2 is ITeleporterReceiver {
    ITeleporterMessenger public immutable teleporterMessenger =
        ITeleporterMessenger(0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf);

    SimpleToken public immutable token;
    address public owner;

    event TokensMinted(address indexed to, uint256 amount);
    event MessageReceived(bytes32 indexed messageId, address indexed sender, uint256 amount);

    constructor() {
        owner = msg.sender;
        // Desplegar el token al crear el contrato
        token = new SimpleToken();
    }

    function receiveTeleporterMessage(bytes32 messageId, address sender, bytes calldata message) external {
        // Verificar que el mensaje viene del Teleporter Messenger
        require(msg.sender == address(teleporterMessenger), "SimpleReceiverOnPrivado: unauthorized TeleporterMessenger");

        // Decodificar el mensaje para obtener el amount
        (uint256 amount) = abi.decode(message, (uint256));

        // Mintear los tokens al sender
        token.mint(sender, amount);

        // Emitir eventos
        emit TokensMinted(sender, amount);
        emit MessageReceived(messageId, sender, amount);
    }

    // Función para verificar el balance de tokens de una dirección
    function getTokenBalance(address account) external view returns (uint256) {
        return token.balanceOf(account);
    }

    // Función para obtener la dirección del token
    function getTokenAddress() external view returns (address) {
        return address(token);
    }
}
