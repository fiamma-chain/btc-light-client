// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Upgrades} from "@openzeppelin-foundry-upgrades/src/Upgrades.sol";

import "../src/BtcMirror.sol";
import "../src/BtcTxVerifier.sol";

contract DeployBtcMirror is Script {
    /**
     * @notice Deploys BtcMirror and BtcTxVerifier, tracking either mainnet or
     *         testnet Bitcoin.
     */
    function run(bool mainnet) external {
        uint256 btcMirrorAdminPrivateKey = vm.envUint("PRIVATE_KEY");
        address btcMirrorAdmin = vm.addr(btcMirrorAdminPrivateKey);

        vm.startBroadcast(btcMirrorAdminPrivateKey);

        address btcMirrorProxyAddress;
        if (mainnet) {
            btcMirrorProxyAddress = Upgrades.deployTransparentProxy(
                "BtcMirror.sol",
                btcMirrorAdmin,
                abi.encodeCall(
                    BtcMirror.initialize,
                    (
                        btcMirrorAdmin,
                        904604, // start at block #904604
                        0x0000000000000000000020a2c3f8c296d11a05c649ab5aa613513da2c2fd19fa,
                        1751983312,
                        0x268160000000000000000000000000000000000000000,
                        false
                    )
                )
            );
        } else {
            btcMirrorProxyAddress = Upgrades.deployTransparentProxy(
                "BtcMirror.sol",
                btcMirrorAdmin,
                abi.encodeCall(
                    BtcMirror.initialize,
                    (
                        btcMirrorAdmin,
                        89926,
                        0x0000000000968ecf4d38c81a8421f1436dcae87651e0f0a96a4c479ae8dda791,
                        1751888323,
                        0x00000000ffff0000000000000000000000000000000000000000000000000000,
                        true
                    )
                )
            );
        }

        // Deploy the transaction verifier
        BtcTxVerifier verifier = new BtcTxVerifier(btcMirrorProxyAddress);

        console2.log("\nDeployment Summary:");
        console2.log("------------------");
        console2.log("BtcMirror Proxy:", btcMirrorProxyAddress);
        console2.log("BtcTxVerifier:", address(verifier));

        vm.stopBroadcast();
    }
}
