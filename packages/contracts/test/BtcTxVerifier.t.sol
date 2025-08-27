// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "forge-std/console.sol";

import "../src/BtcMirror.sol";
import "../src/BtcTxVerifier.sol";

contract BtcTxVerifierTest is Test {
    // correct header for bitcoin block #717695
    // all bitcoin header values are little-endian:
    bytes constant b717695 = (
        hex"04002020" hex"edae5e1bd8a0e007e529fe33d099ebb7a82a06d6d63d0b000000000000000000"
        hex"f8aec519bcd878c9713dc8153a72fd62e3667c5ade70d8d0415584b8528d79ca" hex"0b40d961" hex"ab980b17" hex"3dcc4d5a"
    );

    function createBtcMirror(
        address admin,
        uint256 blockHeight,
        bytes32 blockHash,
        uint256 blockTime,
        uint256 expectedTarget,
        bool isTestnet
    ) internal returns (BtcMirror) {
        // Deploy implementation
        BtcMirror mirrorImpl = new BtcMirror();

        // Deploy ProxyAdmin
        ProxyAdmin proxyAdmin = new ProxyAdmin(address(this));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            BtcMirror.initialize.selector, admin, blockHeight, blockHash, blockTime, expectedTarget, isTestnet
        );

        // Deploy and initialize proxy
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(mirrorImpl), address(proxyAdmin), initData);

        return BtcMirror(address(proxy));
    }

    function testVerifyTx() public {
        BtcMirror mirror = createBtcMirror(
            address(this),
            736000, // start at block #736000
            0x00000000000000000002d52d9816a419b45f1f0efe9a9df4f7b64161e508323d,
            0,
            0x0,
            false
        );
        assertEq(mirror.getLatestBlockHeight(), 736000);

        BtcTxVerifier verif = new BtcTxVerifier(address(mirror));

        // validate payment 736000 #1
        bytes memory header736000 = (
            hex"04000020" hex"d8280f9ce6eeebd2e117f39e1af27cb17b23c5eae6e703000000000000000000"
            hex"31b669b35884e22c31b286ed8949007609db6cb50afe8b6e6e649e62cc24e19c" hex"a5657c62" hex"ba010917"
            hex"36d09865"
        );
        bytes memory txProof736 = (
            hex"d298f062a08ccb73abb327f01d2e2c6109a363ac0973abc497eec663e08a6a13"
            hex"2e64222ee84f7b90b3c37ed29e4576c41868c7dcf73b1183c1c84a73c3bb0451"
            hex"ea4cc81f31578f895bd3c14fcfdd9273173e754bddca44252f261e28ba814b8a"
            hex"d3199dac99561c60e9ea390d15633534de8864c7eb37512c6a6efa1e248e91e5"
            hex"fb0f53df4e177151d7b0a41d7a49d42f4dcf5984f6198b223112d20cf6ae41ed"
            hex"b0914821bd72a12b518dc94e140d651b7a93e5bb7671b3c8821480b0838740ab"
            hex"19d90729a753c500c9dc22cc7fec9a36f9f42597edbf15ccd1d68847cf76da67"
            hex"bc09b6091ec5863f23a2f4739e4c6ba28bb7ba9bcf2266527647194e0fccd94a"
            hex"e6925c8491e0ff7e5a7db9d35c5c15f1cccc49b082fc31b1cc0a364ca1ecc358"
            hex"d7ff70aa2af09f007a0aba4e1df6e850906d22a4c3cc23cd3b87ba0cb3a57e33"
            hex"fb1f9877e50b5cbb8b88b2db234687ea108ac91a232b2472f96f08f136a5eba4"
            hex"0b2be0cdd7773b1ddd2b847c14887d9005daf04da6188f9beeccab698dcc26b9"
        );
        bytes32 txId736 = 0x3667d5beede7d89e41b0ec456f99c93d6cc5e5caff4c4a5f993caea477b4b9b9;
        bytes memory tx736 = (
            hex"02000000" hex"01" hex"bb185dfa5b5c7682f4b2537fe2dcd00ce4f28de42eb4213c68fe57aaa264268b" hex"01000000"
            hex"17" hex"16001407bf360a5fc365d23da4889952bcb59121088ee1" hex"feffffff" hex"02" hex"8085800100000000"
            hex"17" hex"a914ae2f3d4b06579b62574d6178c10c882b9150374087" hex"1c20590500000000" hex"17"
            hex"a91415ecf89e95eb07fbc351b3f7f4c54406f7ee5c1087" hex"00000000"
        );
        bytes memory destScript = hex"a914ae2f3d4b06579b62574d6178c10c882b9150374087";
        bytes32 destScriptHash = sha256(destScript);

        BtcTxProof memory txP = BtcTxProof(header736000, txId736, 1, txProof736, tx736);

        assertTrue(verif.verifyPayment(1, 736000, txP, 0, destScriptHash, 25200000, false, 0, 0));

        vm.expectRevert("Not enough Bitcoin block confirmations");
        assertTrue(!verif.verifyPayment(2, 736000, txP, 0, destScriptHash, 25200000, false, 0, 0));

        vm.expectRevert("Amount mismatch");
        assertTrue(!verif.verifyPayment(1, 736000, txP, 0, destScriptHash, 25200001, false, 0, 0));

        vm.expectRevert("Script mismatch");
        assertTrue(!verif.verifyPayment(1, 736000, txP, 1, destScriptHash, 25200000, false, 0, 0));

        vm.expectRevert("Block hash mismatch");
        assertTrue(!verif.verifyPayment(1, 700000, txP, 0, destScriptHash, 25200000, false, 0, 0));
    }

    function testVerifyP2WSHTx() public {
        BtcMirror mirror = createBtcMirror(
            address(this),
            258185, // start at block #736000
            0x0000000bb2bfb06e7269347c26ae182fa33b3d9429089bf02857cced3ee0c2e6,
            0,
            0x0,
            true
        );
        assertEq(mirror.getLatestBlockHeight(), 258185);

        BtcTxVerifier verif = new BtcTxVerifier(address(mirror));

        // validate payment 258185 #1
        bytes memory header258185 = (
            hex"00000020" hex"7fcd2a7dfd264b8aa41f7e8ae4566e394bb81b55ac53cf3cda4874bd05000000"
            hex"4863e54e0b27e95d2fa01bc88e3d8b5eb500a82b66211a99ff4a52e7c47efe95" hex"7c505f68" hex"0946151d"
            hex"1a8fa608"
        );
        bytes memory txProof258185 = (
            hex"ed6263be5e9cc87c317111bfeef73994eefe5009e986a257f9c56cc37a54f69c"
            hex"4cf8b7a54b774afe1f07f28b7628b86b9733ad0f251fb99ab508a1be69542421"
            hex"49983f1a45962997da1e9e30597df1e00646b738fe4731cb5e4ebedeb2e5701c"
            hex"2eba0c1a8782e8b6e7479e9141615fcc32df25dc72d955e4dd136eeaa552aaf3"
            hex"eb9de918cfe8b85e5f252347fc411b2f67e16d9bab5df4a52359087df1eab598"
            hex"eddd9fa1a9d73601337befd78c938b53ba81a79942c0fe8a348b71bc9a4a05ad"
            hex"801d47d86d0c963fb45b087a127fbd52e624f11830503319ceefdc87d5fe7bfa"
            hex"f4e8776ca7ec0b62f499369b7234165a3fb59f018437b4b23bd314dac7fe9b79"
            hex"3e742253da6efecf5031d59bb40e3cbc55a1495448bdfd6b843e77202d5d2728"
            hex"10114797f417bdba4115017d665086b6a812a3fdf94ab19c386d5562c1db648a"
        );
        bytes32 txId258185 = 0x717169ae85f87f1ace85468a490f15c8c44a92626b530d304d3343e84bc02289;
        // legacy transaction without witness data
        bytes memory tx258185 =
            hex"0200000001a1d5368e173544f905caac1180f994befc12d1e563d7dd04fdb8a8a70b5f35080400000000ffffffff05a08601000000000022002028ef96126ca176dbe4891cd581b697cb05d4ccbb73d78e8ddc6c376aae30cf5f4a0100000000000022512052d19a46c1a8cd90001a816420448b612d9c13bdb50d02d716d411deb94dc9304a010000000000002251205052522694bf08177416fe87545369819499d8481c8158c4f7e6420a9b6654944a01000000000000225120143f25ece73eae253a4e359b3bcb69e0b87e9d6abb1b6abb6bb5821d68eff63343dfe52500000000225120b3fb9347b334c4fce53b7920bc0e1e18b17d2fcd849b743dc8b7243b238e303000000000";
        bytes memory destScript = hex"002028ef96126ca176dbe4891cd581b697cb05d4ccbb73d78e8ddc6c376aae30cf5f";
        bytes32 destScriptHash = sha256(destScript);

        BtcTxProof memory txP = BtcTxProof(header258185, txId258185, 228, txProof258185, tx258185);

        assertTrue(verif.verifyPayment(1, 258185, txP, 0, destScriptHash, 100000, false, 0, 0));

        vm.expectRevert("Not enough Bitcoin block confirmations");
        assertTrue(!verif.verifyPayment(2, 258185, txP, 0, destScriptHash, 100000, false, 0, 0));

        vm.expectRevert("Amount mismatch");
        assertTrue(!verif.verifyPayment(1, 258185, txP, 0, destScriptHash, 100001, false, 0, 0));

        vm.expectRevert("Script mismatch");
        assertTrue(!verif.verifyPayment(1, 258185, txP, 1, destScriptHash, 100000, false, 0, 0));

        vm.expectRevert("Block hash mismatch");
        assertTrue(!verif.verifyPayment(1, 258184, txP, 0, destScriptHash, 100000, false, 0, 0));
    }

    function testVerifyP2TRTx2() public {
        BtcMirror mirror = createBtcMirror(
            address(this),
            258691, // start at block #258691
            0x0000000407b2b6cc1ceefa2e1ac83c5b7e8a9b41306338202de23e77a7d8839a,
            0,
            0x0,
            true
        );
        assertEq(mirror.getLatestBlockHeight(), 258691);

        BtcTxVerifier verif = new BtcTxVerifier(address(mirror));

        // validate payment 258691 #1
        bytes memory header258691 = (
            hex"00000020" hex"0d539094157c80001610c88394d068a5db07bec83baa6911f30739860f000000"
            hex"69c065a7ac4200fac94ac15184ae5b7c4919a3c1aae9c999dd210bdaa4531212" hex"c9066468" hex"0946151d"
            hex"fb2dc006"
        );
        bytes memory txProof258691 = (
            hex"ec1878972884279ac2063c54b5d479870142a3bdcd12fb99ef5a4f9a8cab3fef"
            hex"85864dbcd8eb5f0cc927c1a0f79a37170c57199f528d80b463e596d4c8d3ae33"
            hex"846a8cbef442010cb03d5f29bda81b25868ae28b0440d8905f8aac2b07f5e0ba"
            hex"4dd54d30dc4cf21be24751e4e7f5aaae5535950fd3774508055dc61a35c02afb"
            hex"a58f2f061dd516b236e2ea1f369677d1b23b6a0333b3ae0f08004479607ff27f"
            hex"b391a4c0c70d32bda5cdc089206582ceac2f3a1a102d4ca09de1b30bc7c287c9"
            hex"51784d5581edb1254ab4e0ab42a30099c58d290126767c0147b3d8ccc47ac255"
            hex"d0a0a315449f54896b7870e7a0272c6d59a5a7cfba199bd79269c23bac7b2ba5"
        );
        bytes32 txId258691 = 0xf6c92ed993f3ad532cdb6b5fe4868a31fa2315339f76f4e4e6d84991a7b939fd;
        bytes memory tx258691 =
            hex"02000000011c51c1b148deecc778e269568e021e3f48747ae01808d23f34303581a0c4e7440000000000ffffffff05ac7f0100000000002251203da465252bc8d0d8edf793168780b2e6574f182acd07d133b9e520368493cc53940200000000000022512052d19a46c1a8cd90001a816420448b612d9c13bdb50d02d716d411deb94dc930102700000000000022512076cd54985a86b449f1b177b39e1dbb6aa69802d37a186a4c44591fc9905c11bd102700000000000022512076cd54985a86b449f1b177b39e1dbb6aa69802d37a186a4c44591fc9905c11bd647800000000000022512024768243b3fbcbe285987d62f714277b7676f154d03240cdd3f6c934da966dc600000000";
        bytes memory destScript = hex"51203da465252bc8d0d8edf793168780b2e6574f182acd07d133b9e520368493cc53";
        bytes32 destScriptHash = sha256(destScript);

        BtcTxProof memory txP = BtcTxProof(header258691, txId258691, 175, txProof258691, tx258691);

        assertTrue(verif.verifyPayment(1, 258691, txP, 0, destScriptHash, 98220, false, 0, 0));

        vm.expectRevert("Not enough Bitcoin block confirmations");
        assertTrue(!verif.verifyPayment(2, 258691, txP, 0, destScriptHash, 98220, false, 0, 0));

        vm.expectRevert("Amount mismatch");
        assertTrue(!verif.verifyPayment(1, 258691, txP, 0, destScriptHash, 98221, false, 0, 0));

        vm.expectRevert("Script mismatch");
        assertTrue(!verif.verifyPayment(1, 258691, txP, 0, bytes32(hex"00"), 98220, false, 0, 0));

        vm.expectRevert("Block hash mismatch");
        assertTrue(!verif.verifyPayment(1, 258690, txP, 0, destScriptHash, 98220, false, 0, 0));
    }

    function testVerifyP2TRTx() public {
        BtcMirror mirror = createBtcMirror(
            address(this),
            251954, // start at block #251954
            0x00000008ab60e9910037c17a403348eddb4577e556bc0c336b7e0f02c7c8f44b,
            0,
            0x0,
            true
        );
        assertEq(mirror.getLatestBlockHeight(), 251954);

        BtcTxVerifier verif = new BtcTxVerifier(address(mirror));

        // validate payment 251954 #1
        bytes memory header251954 = (
            hex"00000020" hex"69f1a0e5a60772aa04e7d78331216e7adf293939fda463520ac2a2fc06000000"
            hex"d2594ddc547b58c21f86f608ac0f9dfab10da69ac2ffed0e734897eb61502312" hex"0c572368" hex"b09a0e1d"
            hex"55a2f21a"
        );
        bytes memory txProof251954 = (
            hex"7ccd110a3460e6082a88e7fb126a0e27fb823e5b62565778a94bf169e6026c05"
            hex"22e501d84be7b293f56d25c086c8de0dd77c8f63eea0923e8f0f2dcf2d3e866c"
            hex"9aafa5a4881feb7ee437bcee6f7839cb44996e73f05f4e1eab7e08753159433c"
            hex"166d531331fc9b625de9009f02b66ed3e4e88264b2ff78cbb3e8c63db9d148a6"
            hex"c55cd53abc6f3b384dc4f3cf2a72a04bda89414c5d58b88854e1465a2076b000"
            hex"517c14a131aa288e2e07879d00062372fa492bb6bf9731e057095de4d3462f14"
            hex"3389fe88688e15f0f37e3e03d1d5b4fabc9d5f83be250d1bb783bdcfd3a7b232"
        );
        bytes32 txId251954 = 0x516bec8e1539127d4d645651db92c34518de9c97c37d914bc24f8e6ec99ffb6c;
        bytes memory tx251954 =
            hex"020000000127746ae8ab9fe560a680f7b35d443745aa50190976b1187afae0d1c694adedac0000000000fdffffff015139936f090000002251204875e52611f7c3233ce8633a79baea5bea760ce36b3f49308b655b92c101d10630d80300";
        bytes memory destScript = hex"51204875e52611f7c3233ce8633a79baea5bea760ce36b3f49308b655b92c101d106";
        bytes32 destScriptHash = sha256(destScript);

        BtcTxProof memory txP = BtcTxProof(header251954, txId251954, 2, txProof251954, tx251954);

        assertTrue(verif.verifyPayment(1, 251954, txP, 0, destScriptHash, 40526625105, false, 0, 0));

        vm.expectRevert("Not enough Bitcoin block confirmations");
        assertTrue(!verif.verifyPayment(2, 251954, txP, 0, destScriptHash, 40526625105, false, 0, 0));

        vm.expectRevert("Amount mismatch");
        assertTrue(!verif.verifyPayment(1, 251954, txP, 0, destScriptHash, 40526625106, false, 0, 0));

        vm.expectRevert("Script mismatch");
        assertTrue(!verif.verifyPayment(1, 251954, txP, 0, bytes32(hex"00"), 40526625106, false, 0, 0));

        vm.expectRevert("Block hash mismatch");
        assertTrue(!verif.verifyPayment(1, 251952, txP, 0, destScriptHash, 40526625105, false, 0, 0));
    }
}
