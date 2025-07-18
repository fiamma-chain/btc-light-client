// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {console2} from "forge-std/console2.sol";

import "../src/BtcMirror.sol";

contract BtcMirrorTest is Test {
    uint256 constant ownerPrivateKey = uint256(keccak256(abi.encodePacked("owner")));
    address owner = vm.addr(ownerPrivateKey);

    // correct header for bitcoin block #717695
    // all bitcoin header values are little-endian:
    bytes constant bVer = hex"04002020";
    bytes constant bParent = hex"edae5e1bd8a0e007e529fe33d099ebb7a82a06d6d63d0b000000000000000000";
    bytes constant bTxRoot = hex"f8aec519bcd878c9713dc8153a72fd62e3667c5ade70d8d0415584b8528d79ca";
    bytes constant bTime = hex"0b40d961";
    bytes constant bBits = hex"ab980b17";
    bytes constant bNonce = hex"3dcc4d5a";

    // correct header for bitcoin block #717696
    // in order, all little-endian:
    // - version
    // - parent hash
    // - tx merkle root
    // - timestamp
    // - difficulty bits
    // - nonce
    bytes constant b717696 = (
        hex"00004020" hex"9acaa5d26d392ace656c2428c991b0a3d3d773845a1300000000000000000000"
        hex"aa8e225b1f3ea6c4b7afd5aa1cecf691a8beaa7fa1e579ce240e4a62b5ac8ecc" hex"2141d961" hex"8b8c0b17" hex"0d5c05bb"
    );

    bytes constant b717697 = (
        hex"0400c020" hex"bf559a5b0479c2a73627af40cef1835d44de7b32dd3503000000000000000000"
        hex"fe7be65b41f6cf522eac2a63f9dde1f7a6f61eee93c648c74b79cfc242dd1a94" hex"f241d9618b8c0b17ac09604c"
    );

    bytes headerGood = bytes.concat(bVer, bParent, bTxRoot, bTime, bBits, bNonce);

    bytes headerWrongParentHash = bytes.concat(
        hex"04002020", // version
        hex"0000000000000000000000000000000000000000000000000000000000000000", // parent hash
        hex"f8aec519bcd878c9713dc8153a72fd62e3667c5ade70d8d0415584b8528d79ca", // merkle root
        hex"0b40d961", // timestamp
        hex"ab980b17", // bits
        hex"3dcc4d5a" // nonce
    );

    bytes headerWrongLength = bytes.concat(bVer, bParent, bTxRoot, bTime, bBits, bNonce, hex"00");

    bytes headerHashTooEasy = bytes.concat(
        hex"04002020", // version
        hex"edae5e1bd8a0e007e529fe33d099ebb7a82a06d6d63d0b000000000000000000", // parent hash
        hex"f8aec519bcd878c9713dc8153a72fd62e3667c5ade70d8d0415584b8528d79ca", // merkle root
        hex"0b40d961", // timestamp
        hex"ab980b17", // bits
        hex"00000000" // nonce
    );

    function testGetTarget() public {
        BtcMirror mirror = createBtcMirror();
        uint256 expectedTarget;
        expectedTarget = 0x0000000000000000000B8C8B0000000000000000000000000000000000000000;
        assertEq(mirror.getTarget(hex"8b8c0b17"), expectedTarget);
        expectedTarget = 0x00000000000404CB000000000000000000000000000000000000000000000000;
        assertEq(mirror.getTarget(hex"cb04041b"), expectedTarget);
        expectedTarget = 0x000000000000000000096A200000000000000000000000000000000000000000;
        assertEq(mirror.getTarget(hex"206a0917"), expectedTarget);
    }

    // function testSubmitErrorFuzz1(bytes calldata x) public {
    //     vm.expectRevert("");
    //     mirror.submit(718115, x);
    //     assert(mirror.getLatestBlockHeight() == 718115);
    // }

    // function testSubmitErrorFuzz2(uint256 height, bytes calldata x) public {
    //     vm.expectRevert("");
    //     mirror.submit(height, x);
    //     assert(mirror.getLatestBlockHeight() == 718115);
    // }

    event NewTip(uint256 blockHeight, uint256 blockTime, bytes32 blockHash);
    event NewTotalDifficultySinceRetarget(uint256 blockHeight, uint256 totalDifficulty, uint32 newDifficultyBits);

    function createBtcMirror() internal returns (BtcMirror mirror) {
        // Deploy implementation
        BtcMirror mirrorImpl = new BtcMirror();

        // Deploy ProxyAdmin
        ProxyAdmin proxyAdmin = new ProxyAdmin(address(this));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            BtcMirror.initialize.selector,
            owner,
            717694, // start at block #717694, two blocks before retarget
            0x0000000000000000000b3dd6d6062aa8b7eb99d033fe29e507e0a0d81b5eaeed,
            1641627092,
            0x0000000000000000000B98AB0000000000000000000000000000000000000000,
            true // use testnet mode
        );

        // Deploy and initialize proxy
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(mirrorImpl), address(proxyAdmin), initData);

        mirror = BtcMirror(address(proxy));

        // Set initial target for period 356
        bytes memory initialHeader = bytes.concat(
            hex"04002020", // version
            hex"edae5e1bd8a0e007e529fe33d099ebb7a82a06d6d63d0b000000000000000000", // parent hash
            hex"f8aec519bcd878c9713dc8153a72fd62e3667c5ade70d8d0415584b8528d79ca", // merkle root
            hex"0b40d961", // timestamp
            hex"ab980b17", // bits
            hex"3dcc4d5a" // nonce
        );
        bytes32 hash = keccak256(abi.encode(uint256(717694), initialHeader));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        vm.prank(owner);
        mirror.submit_uncheck(717694, initialHeader, v, r, s);
    }

    function testChallenge() public {
        BtcMirror mirror = createBtcMirror();
        assertEq(mirror.getLatestBlockHeight(), 717694);

        bytes32 prevBlockHash = mirror.getBlockHash(717694);
        console2.log("717694 prevBlockHash");
        console2.logBytes32(prevBlockHash);

        // First submit a valid block
        bytes32 hash = keccak256(abi.encode(uint256(717695), headerGood));
        (uint8 goodV, bytes32 goodR, bytes32 goodS) = vm.sign(ownerPrivateKey, hash);
        vm.prank(owner);
        mirror.submit_uncheck(717695, headerGood, goodV, goodR, goodS);

        // Test challenge genesis block
        hash = keccak256(abi.encode(uint256(0), headerWrongParentHash));
        (uint8 badV, bytes32 badR, bytes32 badS) = vm.sign(ownerPrivateKey, hash);
        vm.prank(owner);
        vm.expectRevert("The genesis block cannot be challenged");
        mirror.challenge(0, headerWrongParentHash, badV, badR, badS, 0, headerGood);

        // Test wrong signature
        uint256 wrongPrivateKey = uint256(keccak256(abi.encodePacked("wrong")));
        (uint8 wrongV, bytes32 wrongR, bytes32 wrongS) = vm.sign(wrongPrivateKey, hash);
        vm.prank(owner);
        vm.expectRevert("Challenger use wrong signature");
        mirror.challenge(0, headerWrongParentHash, wrongV, wrongR, wrongS, 717695, headerGood);
    }

    function testRetarget() public {
        BtcMirror mirror = createBtcMirror();
        assertEq(mirror.getLatestBlockHeight(), 717694);

        // Submit first block
        bytes32 hash = keccak256(abi.encode(uint256(717695), headerGood));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        vm.prank(owner);
        mirror.submit_uncheck(717695, headerGood, v, r, s);
        assertEq(mirror.getLatestBlockHeight(), 717695);

        // Submit second block
        hash = keccak256(abi.encode(uint256(717696), b717696));
        (v, r, s) = vm.sign(ownerPrivateKey, hash);
        vm.prank(owner);
        mirror.submit_uncheck(717696, b717696, v, r, s);

        assertEq(mirror.getLatestBlockHeight(), 717696);
        assertEq(mirror.getLatestBlockTime(), 1641627937);
        assertEq(mirror.getBlockHash(717696), 0x0000000000000000000335dd327bde445d83f1ce40af2736a7c279045b9a55bf);
    }

    function testRetargetLonger() public {
        BtcMirror mirror = createBtcMirror();
        assertEq(mirror.getLatestBlockHeight(), 717694);

        // Submit first block
        bytes32 hash = keccak256(abi.encode(uint256(717695), headerGood));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        vm.prank(owner);
        mirror.submit_uncheck(717695, headerGood, v, r, s);
        assertEq(mirror.getLatestBlockHeight(), 717695);

        // Submit multiple blocks
        bytes memory multipleHeaders = bytes.concat(b717696, b717697);
        hash = keccak256(abi.encode(uint256(717696), multipleHeaders));
        (v, r, s) = vm.sign(ownerPrivateKey, hash);
        vm.prank(owner);
        mirror.submit_uncheck(717696, multipleHeaders, v, r, s);
        assertEq(mirror.getLatestBlockHeight(), 717697);
    }

    function testSubmitUncheck() public {
        BtcMirror mirror = createBtcMirror();
        assertEq(mirror.getLatestBlockHeight(), 717694);

        // Prepare signature data
        bytes32 hash = keccak256(abi.encode(uint256(717695), headerGood));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

        // Test non-owner cannot call
        address nonOwner = address(0x9999999999999999999999999999999999999999);
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        mirror.submit_uncheck(717695, headerGood, v, r, s);

        // Test invalid signature
        vm.startPrank(owner);
        vm.expectRevert("Invalid signature");
        mirror.submit_uncheck(717695, headerGood, v, r, bytes32(0));

        // Test successful submission
        vm.expectEmit(true, true, true, true);
        emit NewTip(717695, 1641627659, 0x00000000000000000000135a8473d7d3a3b091c928246c65ce2a396dd2a5ca9a);
        mirror.submit_uncheck(717695, headerGood, v, r, s);

        // Verify state updates
        assertEq(mirror.getLatestBlockHeight(), 717695);
        assertEq(mirror.getLatestBlockTime(), 1641627659);
        assertEq(mirror.getBlockHash(717695), 0x00000000000000000000135a8473d7d3a3b091c928246c65ce2a396dd2a5ca9a);

        // Test submitting multiple blocks
        bytes memory twoHeaders = bytes.concat(headerGood, b717696);
        hash = keccak256(abi.encode(uint256(717695), twoHeaders));
        (v, r, s) = vm.sign(ownerPrivateKey, hash);

        vm.expectEmit(true, true, true, true);
        emit NewTip(717696, 1641627937, 0x0000000000000000000335dd327bde445d83f1ce40af2736a7c279045b9a55bf);
        mirror.submit_uncheck(717695, twoHeaders, v, r, s);

        // Verify state updates
        assertEq(mirror.getLatestBlockHeight(), 717696);
        assertEq(mirror.getLatestBlockTime(), 1641627937);
        assertEq(mirror.getBlockHash(717696), 0x0000000000000000000335dd327bde445d83f1ce40af2736a7c279045b9a55bf);
        vm.stopPrank();
    }

    function testSubmitUncheckError() public {
        BtcMirror mirror = createBtcMirror();

        // Prepare signature data with wrong private key
        uint256 wrongPrivateKey = uint256(keccak256(abi.encodePacked("wrong")));

        bytes32 hash = keccak256(abi.encode(uint256(717695), headerWrongLength));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, hash);

        // Test invalid signature
        vm.startPrank(owner);
        vm.expectRevert("Invalid signature");
        mirror.submit_uncheck(717695, headerWrongLength, v, r, s);

        // Test invalid header length with correct signature
        hash = keccak256(abi.encode(uint256(717695), headerWrongLength));
        (v, r, s) = vm.sign(ownerPrivateKey, hash);
        vm.expectRevert("wrong header length");
        mirror.submit_uncheck(717695, headerWrongLength, v, r, s);

        // Test empty header
        hash = keccak256(abi.encode(uint256(717695), ""));
        (v, r, s) = vm.sign(ownerPrivateKey, hash);
        vm.expectRevert("must submit at least one block");
        mirror.submit_uncheck(717695, "", v, r, s);
        vm.stopPrank();
    }
}
