// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Project imports
import {LzBtcMirror} from "../src/LzBtcMirror.sol";
import {BtcMirror} from "../src/BtcMirror.sol";

// OApp imports
import {IOAppOptionsType3, EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

// Forge imports
import "forge-std/console.sol";
import "forge-std/Test.sol";

// DevTools imports
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract LzBtcMirrorTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private hubEid = 1; // Hub chain (Arbitrum) Endpoint ID
    uint32 private spokeEid = 2; // Spoke chain Endpoint ID

    LzBtcMirror private spokeLzBtcMirror; // Deployed on spoke chain
    BtcMirror private hubBtcMirror; // Deployed on hub chain

    address private userA = address(0x1);
    address private deployer = address(0x2);

    uint16 private constant READ_TYPE = 1;

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(deployer, 1000 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy BtcMirror on hub chain (hubEid)
        vm.prank(deployer);
        hubBtcMirror = BtcMirror(
            _deployOApp(type(BtcMirror).creationCode, abi.encode())
        );

        // Deploy LzBtcMirror on spoke chain (spokeEid)
        spokeLzBtcMirror = LzBtcMirror(
            payable(
                _deployOApp(
                    type(LzBtcMirror).creationCode,
                    abi.encode(
                        address(endpoints[spokeEid]), // LayerZero endpoint
                        address(this), // owner/delegate
                        DEFAULT_CHANNEL_ID, // read channel
                        hubEid, // target chain EID
                        address(hubBtcMirror) // target BtcMirror address
                    )
                )
            )
        );

        // Wire the OApps for reading
        address[] memory oapps = new address[](1);
        oapps[0] = address(spokeLzBtcMirror);
        uint32[] memory channels = new uint32[](1);
        channels[0] = DEFAULT_CHANNEL_ID;
        this.wireReadOApps(oapps, channels);
    }

    function test_constructor() public view {
        assertEq(spokeLzBtcMirror.owner(), address(this));
        assertEq(
            address(spokeLzBtcMirror.endpoint()),
            address(endpoints[spokeEid])
        );
        assertEq(spokeLzBtcMirror.targetEid(), hubEid);
        assertEq(spokeLzBtcMirror.targetBtcMirror(), address(hubBtcMirror));
    }

    function test_readData() public {
        // First, add some test data to the hub BtcMirror
        vm.prank(deployer);
        // Note: You'll need to add proper block data to BtcMirror for this test
        // This is a simplified test that assumes BtcMirror has some data

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReadOption(1e8, 100, 0);

        uint256 blockNumber = 123456;

        // Estimate the fee
        MessagingFee memory fee = spokeLzBtcMirror.quoteReadFee(
            blockNumber,
            options
        );

        // Record logs to capture the DataReceived event
        vm.recordLogs();

        // User A initiates the read request
        vm.prank(userA);
        spokeLzBtcMirror.readData{value: fee.nativeFee}(blockNumber, options);

        // Mock response data - in real scenario this would come from hub BtcMirror
        uint256 mockLatestHeight = 123500;
        bytes32 mockBlockHash = keccak256(
            abi.encodePacked("mock_block_hash", blockNumber)
        );

        // Process the response packet, injecting mock data
        // Note: Response data follows the format: (latestHeight, blockNumber, blockHash)
        bytes memory responseData = abi.encode(
            mockLatestHeight,
            blockNumber,
            mockBlockHash
        );
        this.verifyPackets(
            spokeEid,
            addressToBytes32(address(spokeLzBtcMirror)),
            0,
            address(0x0),
            responseData
        );

        // Verify the data was received and stored
        assertEq(spokeLzBtcMirror.getBlockHash(blockNumber), mockBlockHash);
        assertEq(spokeLzBtcMirror.getLatestBlockHeight(), mockLatestHeight);

        // Retrieve the logs to verify the DataReceived event
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool found = false;
        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory entry = entries[i];
            // Check for DataReceived event signature: DataReceived(uint256,uint256,bytes32)
            if (
                entry.topics[0] ==
                keccak256("DataReceived(uint256,uint256,bytes32)") &&
                entry.topics.length == 4 // signature + 3 indexed parameters
            ) {
                // Indexed parameters are stored in topics, not data
                uint256 receivedLatestHeight = uint256(entry.topics[1]);
                uint256 receivedBlockNumber = uint256(entry.topics[2]);
                bytes32 receivedBlockHash = entry.topics[3];

                assertEq(receivedBlockNumber, blockNumber);
                assertEq(receivedBlockHash, mockBlockHash);
                assertEq(receivedLatestHeight, mockLatestHeight);
                found = true;
                break;
            }
        }
        assertEq(found, true, "DataReceived event not found");
    }

    function test_quoteReadFee() public view {
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReadOption(1e8, 100, 0);
        uint256 blockNumber = 123456;

        MessagingFee memory fee = spokeLzBtcMirror.quoteReadFee(
            blockNumber,
            options
        );

        // Fee should be non-zero
        assertGt(fee.nativeFee, 0);
    }

    function test_getReceivedData_empty() public view {
        uint256 blockNumber = 999999;

        // Should return zero values for non-existent data
        assertEq(spokeLzBtcMirror.getBlockHash(blockNumber), bytes32(0));
        assertEq(spokeLzBtcMirror.getLatestBlockHeight(), 0);
    }
}
