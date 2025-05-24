// (c) 2023, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

// SPDX-License-Identifier: Ecosystem

pragma solidity ^0.8.18;

import "@teleporter/ITeleporterMessenger.sol";

contract SimpleSenderOnCChain {
    ITeleporterMessenger public immutable teleporterMessenger =
        ITeleporterMessenger(0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf);

    // Evento para notificar el envío de números
    event NumbersSent(address destinationAddress, uint256 firstNumber, uint256 secondNumber);

    function sendNumbers(address destinationAddress, uint256 num1, uint256 num2) external {
        teleporterMessenger.sendCrossChainMessage(
            TeleporterMessageInput({
                // BlockchainID of Dispatch L1
                destinationBlockchainID: 0x35126d63d398a10a2ede0893b52eb00863f47d022e7aded472c92b23d5e7ab84,
                destinationAddress: destinationAddress,
                feeInfo: TeleporterFeeInfo({feeTokenAddress: address(0), amount: 0}),
                requiredGasLimit: 100000,
                allowedRelayerAddresses: new address[](0),
                message: encodeNumbers(num1, num2)
            })
        );

        // Emitir evento con los números enviados
        emit NumbersSent(destinationAddress, num1, num2);
    }

    // Función helper para codificar los números
    function encodeNumbers(uint256 a, uint256 b) public pure returns (bytes memory) {
        return abi.encode(a, b);
    }
}
