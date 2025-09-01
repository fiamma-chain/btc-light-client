// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import necessary LayerZero interfaces and contracts
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {ReadCodecV1, EVMCallRequestV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IBtcMirror.sol";

/// @title LzBtcMirror
/// @notice A LayerZero OAppRead contract to read Bitcoin block data from target chain BtcMirror
contract LzBtcMirror is OAppRead, OAppOptionsType3 {
    /// @notice Emitted when combined data is received from target chain
    /// @param blockNumber The requested block number
    /// @param blockHash The block hash
    /// @param latestHeight The latest block height
    event DataReceived(
        uint256 indexed latestHeight,
        uint256 indexed blockNumber,
        bytes32 indexed blockHash
    );

    /// @notice LayerZero read channel ID
    uint32 public READ_CHANNEL;

    /// @notice Message type for the read operation.
    uint16 public constant READ_TYPE = 1;

    /// @notice Target chain ID where BtcMirror is deployed
    uint32 public immutable targetEid;

    /// @notice BtcMirror contract address on target chain
    address public immutable targetBtcMirror;

    /// @notice Storage for received data from cross-chain calls
    mapping(uint256 => bytes32) private receivedBlockHashes;
    uint256 private receivedLatestHeight;

    /**
     * @notice Constructor to initialize the LzBtcMirror contract
     * @param _endpoint The LayerZero endpoint contract address
     * @param _delegate The address that will have ownership privileges
     * @param _readChannel The LayerZero read channel ID
     * @param _targetEid The target chain endpoint ID where BtcMirror is deployed
     * @param _targetBtcMirror The BtcMirror contract address on target chain
     */
    constructor(
        address _endpoint,
        address _delegate,
        uint32 _readChannel,
        uint32 _targetEid,
        address _targetBtcMirror
    ) OAppRead(_endpoint, _delegate) Ownable(_delegate) {
        READ_CHANNEL = _readChannel;
        targetEid = _targetEid;
        targetBtcMirror = _targetBtcMirror;
        _setPeer(_readChannel, AddressCast.toBytes32(address(this)));
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // 0. Quote business logic
    // ──────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Estimates the messaging fee required to perform the read operation.
     * @param blockNumber The Bitcoin block number to read
     * @param _extraOptions Additional messaging options
     * @return fee The estimated messaging fee
     */
    function quoteReadFee(
        uint256 blockNumber,
        bytes calldata _extraOptions
    ) external view returns (MessagingFee memory fee) {
        return
            _quote(
                READ_CHANNEL,
                _getCmd(blockNumber),
                combineOptions(READ_CHANNEL, READ_TYPE, _extraOptions),
                false
            );
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // 1a. Send business logic
    // ──────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Sends a read request to fetch latest height and block hash from target BtcMirror
     * @dev The caller must send enough ETH to cover the messaging fee
     * @param blockNumber The Bitcoin block number to get hash for
     * @param _extraOptions Additional messaging options
     * @return receipt The LayerZero messaging receipt for the request
     */
    function readData(
        uint256 blockNumber,
        bytes calldata _extraOptions
    ) external payable returns (MessagingReceipt memory receipt) {
        // 1. Build the read command for the target BtcMirror
        bytes memory cmd = _getCmd(blockNumber);

        // 2. Send the read request via LayerZero
        return
            _lzSend(
                READ_CHANNEL,
                cmd,
                combineOptions(READ_CHANNEL, READ_TYPE, _extraOptions),
                MessagingFee(msg.value, 0),
                payable(msg.sender)
            );
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // 1b. Read command construction
    // ──────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Constructs the read command to fetch latest height and block hash from target chain
     * @param blockNumber The Bitcoin block number
     * @return cmd The encoded command that specifies what data to read
     */
    function _getCmd(
        uint256 blockNumber
    ) internal view returns (bytes memory cmd) {
        // 1. Define WHAT function to call on the target contract
        bytes memory callData = abi.encodeWithSelector(
            IBtcMirror.getLatestHeightAndBlockHash.selector,
            blockNumber
        );

        // 2. Build the read request specifying WHERE and HOW to fetch the data
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
        readRequests[0] = EVMCallRequestV1({
            appRequestLabel: 1,
            targetEid: targetEid,
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: 15,
            to: targetBtcMirror,
            callData: callData
        });

        // 3. Encode the complete read command
        cmd = ReadCodecV1.encode(0, readRequests);
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // 2. Receive business logic
    // ──────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Handles the received data from target BtcMirror
     * @param _message The data returned from the read request
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        // 1. Decode the returned data (latestHeight, blockNumber, and blockHash)
        (uint256 latestHeight, uint256 blockNumber, bytes32 blockHash) = abi
            .decode(_message, (uint256, uint256, bytes32));

        // 2. Store the received data
        receivedLatestHeight = latestHeight;
        receivedBlockHashes[blockNumber] = blockHash;

        // 3. Emit an event with the received data
        emit DataReceived(latestHeight, blockNumber, blockHash);
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // 3. View functions for received data (compatible with BtcMirror interface)
    // ──────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Get received block hash (compatible with BtcMirror.getBlockHash)
     * @param number The Bitcoin block number
     * @return blockHash The received block hash (zero if not received)
     */
    function getBlockHash(uint256 number) external view returns (bytes32) {
        return receivedBlockHashes[number];
    }

    /**
     * @notice Get received latest height (compatible with BtcMirror.getLatestBlockHeight)
     * @return latestHeight The received latest height
     */
    function getLatestBlockHeight() external view returns (uint256) {
        return receivedLatestHeight;
    }

    /**
     * @notice Returns latest block height and specific block hash in one call
     * @dev Compatible with BtcMirror.getLatestHeightAndBlockHash for unified ABI
     * @param blockNumber The specific block number to get hash for
     * @return latestHeight The latest block height from received data
     * @return requestedBlockNumber The requested block number (echoed back)
     * @return blockHash The hash of the requested block from received data
     */
    function getLatestHeightAndBlockHash(
        uint256 blockNumber
    )
        external
        view
        returns (
            uint256 latestHeight,
            uint256 requestedBlockNumber,
            bytes32 blockHash
        )
    {
        return (
            receivedLatestHeight,
            blockNumber,
            receivedBlockHashes[blockNumber]
        );
    }

    // ──────────────────────────────────────────────────────────────────────────────
    // 4. Admin functions
    // ──────────────────────────────────────────────────────────────────────────────

    /**
     * @notice Sets the LayerZero read channel
     * @param _channelId The channel ID to set
     * @param _active Flag to activate or deactivate the channel
     */
    function setReadChannel(
        uint32 _channelId,
        bool _active
    ) public override onlyOwner {
        _setPeer(
            _channelId,
            _active ? AddressCast.toBytes32(address(this)) : bytes32(0)
        );
        READ_CHANNEL = _channelId;
    }
}
