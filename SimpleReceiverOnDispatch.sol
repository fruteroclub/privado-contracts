// (c) 2023, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

// SPDX-License-Identifier: Ecosystem

pragma solidity ^0.8.18;

import "@teleporter/ITeleporterMessenger.sol";
import "@teleporter/ITeleporterReceiver.sol";

contract SimpleReceiverOnDispatch is ITeleporterReceiver {
    ITeleporterMessenger public immutable teleporterMessenger =
        ITeleporterMessenger(0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf);

    // Variables para almacenar los números recibidos
    uint256 public firstNumber;
    uint256 public secondNumber;

    // Evento para notificar cuando se reciben nuevos números
    event NumbersReceived(uint256 firstNumber, uint256 secondNumber);

    function receiveTeleporterMessage(bytes32, address, bytes calldata message) external {
        // Only the Teleporter receiver can deliver a message.
        require(
            msg.sender == address(teleporterMessenger), "CalculatorReceiverOnDispatch: unauthorized TeleporterMessenger"
        );

        // Decodificar los dos números del mensaje
        (uint256 a, uint256 b) = abi.decode(message, (uint256, uint256));

        // Almacenar los números
        firstNumber = a;
        secondNumber = b;

        // Emitir evento con los números recibidos
        emit NumbersReceived(a, b);
    }

    // Función para obtener ambos números
    function getNumbers() external view returns (uint256, uint256) {
        return (firstNumber, secondNumber);
    }
}
