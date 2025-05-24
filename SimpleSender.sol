// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip@1.6.0/contracts/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts@1.4.0/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip@1.6.0/contracts/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts@1.4.0/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts@1.4.0/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

contract SimpleSender is OwnerIsCreator {
    using SafeERC20 for IERC20;

    error InvalidRouter();
    error InvalidLinkToken();
    error InvalidUsdcToken();
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
    error InvalidDestinationChain();
    error InvalidReceiverAddress();
    error NoReceiverOnDestinationChain(uint64 destinationChainSelector);
    error AmountIsZero();
    error InvalidGasLimit();
    error NoGasLimitOnDestinationChain(uint64 destinationChainSelector);

    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address indexed receiver,
        string orderId,
        address token,
        uint256 tokenAmount,
        address feeToken,
        uint256 fees
    );

    IRouterClient private immutable i_router;
    IERC20 private immutable i_linkToken;
    IERC20 private immutable i_usdcToken;

    mapping(uint64 => address) public s_receivers;
    mapping(uint64 => uint256) public s_gasLimits;

    modifier validateDestinationChain(uint64 _destinationChainSelector) {
        if (_destinationChainSelector == 0) revert InvalidDestinationChain();
        _;
    }

    constructor(address _router, address _link, address _usdcToken) {
        if (_router == address(0)) revert InvalidRouter();
        if (_link == address(0)) revert InvalidLinkToken();
        if (_usdcToken == address(0)) revert InvalidUsdcToken();
        i_router = IRouterClient(_router);
        i_linkToken = IERC20(_link);
        i_usdcToken = IERC20(_usdcToken);
    }

    function setReceiverForDestinationChain(
        uint64 _destinationChainSelector,
        address _receiver
    ) external onlyOwner validateDestinationChain(_destinationChainSelector) {
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        s_receivers[_destinationChainSelector] = _receiver;
    }

    function setGasLimitForDestinationChain(
        uint64 _destinationChainSelector,
        uint256 _gasLimit
    ) external onlyOwner validateDestinationChain(_destinationChainSelector) {
        if (_gasLimit == 0) revert InvalidGasLimit();
        s_gasLimits[_destinationChainSelector] = _gasLimit;
    }

    function sendMessagePayLINK(
        uint64 _destinationChainSelector,
        string memory _orderId,
        uint256 _amount
    ) external onlyOwner validateDestinationChain(_destinationChainSelector) returns (bytes32 messageId) {
        address receiver = s_receivers[_destinationChainSelector];
        if (receiver == address(0)) revert NoReceiverOnDestinationChain(_destinationChainSelector);
        if (_amount == 0) revert AmountIsZero();
        uint256 gasLimit = s_gasLimits[_destinationChainSelector];
        if (gasLimit == 0) revert NoGasLimitOnDestinationChain(_destinationChainSelector);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(i_usdcToken),
            amount: _amount
        });

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(_orderId),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({
                    gasLimit: gasLimit,
                    allowOutOfOrderExecution: true
                })
            ),
            feeToken: address(i_linkToken)
        });

        uint256 fees = i_router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > i_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(i_linkToken.balanceOf(address(this)), fees);

        i_linkToken.approve(address(i_router), fees);
        i_usdcToken.approve(address(i_router), _amount);

        messageId = i_router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        emit MessageSent(
            messageId,
            _destinationChainSelector,
            receiver,
            _orderId,
            address(i_usdcToken),
            _amount,
            address(i_linkToken),
            fees
        );

        return messageId;
    }

    function withdrawLinkToken(address _beneficiary) public onlyOwner {
        uint256 amount = i_linkToken.balanceOf(address(this));
        if (amount == 0) revert NotEnoughBalance(0, 0);
        i_linkToken.safeTransfer(_beneficiary, amount);
    }

    function withdrawUsdcToken(address _beneficiary) public onlyOwner {
        uint256 amount = i_usdcToken.balanceOf(address(this));
        if (amount == 0) revert NotEnoughBalance(0, 0);
        i_usdcToken.safeTransfer(_beneficiary, amount);
    }
} 