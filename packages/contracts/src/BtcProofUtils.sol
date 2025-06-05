// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Endian.sol";
import "./interfaces/BtcTxProof.sol";

/*
 * USAGE EXAMPLE FOR OP_RETURN ADDRESS VERIFICATION:
 *
 * // Payment validation with automatic OP_RETURN address verification
 * bool isValid = BtcProofUtils.validatePayment(
 *     blockHash,
 *     txProof,
 *     1, // payment output index (OP_RETURN is always index 0)
 *     destScriptHash,
 *     1000000, // 0.01 BTC in satoshis
 *     0x742d35Cc6634C0532925a3b8D9c02AA02fc1238e // expected recipient address
 * );
 *
 * The Bitcoin transaction must have:
 * - Output 0: OP_RETURN 0x14 <20-byte-ethereum-address> (required)
 * - Output 1+: P2WSH payment to destScriptHash with specified amount
 *
 * This prevents malicious actors from using valid BTC transactions
 * to mint tokens for different addresses on the sidechain.
 */

/**
 * @dev A parsed (but NOT fully validated) Bitcoin transaction.
 */
struct BitcoinTx {
    /**
     * @dev Whether we successfully parsed this Bitcoin TX, valid version etc.
     *      Does NOT check signatures or whether inputs are unspent.
     */
    bool validFormat;
    /**
     * @dev Version. Must be 1 or 2.
     */
    uint32 version;
    /**
     * @dev Each input spends a previous UTXO.
     */
    BitcoinTxIn[] inputs;
    /**
     * @dev Each output creates a new UTXO.
     */
    BitcoinTxOut[] outputs;
    /**
     * @dev Locktime. Either 0 for no lock, blocks if <500k, or seconds.
     */
    uint32 locktime;
}

struct BitcoinTxIn {
    /** @dev Previous transaction. */
    uint256 prevTxID;
    /** @dev Specific output from that transaction. */
    uint32 prevTxIndex;
    /** @dev Mostly useless for tx v1, BIP68 Relative Lock Time for tx v2. */
    uint32 seqNo;
    /** @dev Input script length */
    uint32 scriptLen;
    /** @dev Input script, spending a previous UTXO. Over 32 bytes unsupported. */
    bytes32 script;
}

struct BitcoinTxOut {
    /** @dev TXO value, in satoshis */
    uint64 valueSats;
    /** @dev Output script length */
    uint32 scriptLen;
    /** @dev Output script. Over 32 bytes unsupported.  */
    bytes script;
}

//
//                                        #
//                                       # #
//                                      # # #
//                                     # # # #
//                                    # # # # #
//                                   # # # # # #
//                                  # # # # # # #
//                                 # # # # # # # #
//                                # # # # # # # # #
//                               # # # # # # # # # #
//                              # # # # # # # # # # #
//                                   # # # # # #
//                               +        #        +
//                                ++++         ++++
//                                  ++++++ ++++++
//                                    +++++++++
//                                      +++++
//                                        +
//
// BtcProofUtils provides functions to prove things about Bitcoin transactions.
// Verifies merkle inclusion proofs, transaction IDs, and payment details.
library BtcProofUtils {
    /**
     * @dev Validates that a given payment appears under a given block hash.
     *
     * This verifies all of the following:
     * 1. Raw transaction really does pay X satoshis to Y script hash.
     * 2. Raw transaction hashes to the given transaction ID.
     * 3. Transaction ID appears under transaction root (Merkle proof).
     * 4. Transaction root is part of the block header.
     * 5. Block header hashes to a given block hash.
     * 6. OP_RETURN output (index 0) contains the expected recipient address.
     *
     * The caller must separately verify that the block hash is in the chain.
     *
     * Always returns true or reverts with a descriptive reason.
     */
    function validatePayment(
        bytes32 blockHash,
        BtcTxProof calldata txProof,
        uint256 txOutIx,
        bytes32 destScriptHash,
        uint256 satoshisExpected,
        address to
    ) internal pure returns (bool) {
        // 1. Block header to block hash
        require(
            getBlockHash(txProof.blockHeader) == blockHash,
            "Block hash mismatch"
        );

        // 2. and 3. Transaction ID included in block
        bytes32 blockTxRoot = getBlockTxMerkleRoot(txProof.blockHeader);
        bytes32 txRoot = getTxMerkleRoot(
            txProof.txId,
            txProof.txIndex,
            txProof.txMerkleProof
        );
        require(blockTxRoot == txRoot, "Tx merkle root mismatch");

        // 4. Raw transaction to TxID
        require(getTxID(txProof.rawTx) == txProof.txId, "Tx ID mismatch");

        // 5. Parse and validate transaction structure
        BitcoinTx memory parsedTx = parseBitcoinTx(txProof.rawTx);
        require(
            parsedTx.outputs.length >= 2,
            "Transaction must have at least 2 outputs"
        );
        require(
            txOutIx < parsedTx.outputs.length,
            "Invalid payment output index"
        );

        // 6. Validate OP_RETURN output (index 0) contains the expected recipient address
        BitcoinTxOut memory opReturnTxo = parsedTx.outputs[0];
        address extractedAddress = getAddressFromOpReturn(
            opReturnTxo.scriptLen,
            opReturnTxo.script
        );
        require(
            extractedAddress != address(0),
            "Invalid OP_RETURN script format"
        );
        require(extractedAddress == to, "OP_RETURN address mismatch");

        // 7. Finally, validate raw transaction pays stated recipient.
        BitcoinTxOut memory txo = parsedTx.outputs[txOutIx];
        bytes32 actualScriptHash = getP2WSH(txo.scriptLen, txo.script);
        require(destScriptHash == actualScriptHash, "Script hash mismatch");
        require(txo.valueSats == satoshisExpected, "Amount mismatch");

        // We've verified that blockHash contains a P2WSH transaction
        // that sends satoshisExpected to the given hash and the recipient address matches.
        return true;
    }

    /**
     * @dev Compute a block hash given a block header.
     */
    function getBlockHash(
        bytes calldata blockHeader
    ) public pure returns (bytes32) {
        require(blockHeader.length == 80);
        bytes32 ret = sha256(abi.encodePacked(sha256(blockHeader)));
        return bytes32(Endian.reverse256(uint256(ret)));
    }

    /**
     * @dev Get the transactions merkle root given a block header.
     */
    function getBlockTxMerkleRoot(
        bytes calldata blockHeader
    ) public pure returns (bytes32) {
        require(blockHeader.length == 80);
        return bytes32(blockHeader[36:68]);
    }

    /**
     * @dev Recomputes the transactions root given a merkle proof.
     */
    function getTxMerkleRoot(
        bytes32 txId,
        uint256 txIndex,
        bytes calldata siblings
    ) public pure returns (bytes32) {
        bytes32 ret = bytes32(Endian.reverse256(uint256(txId)));
        uint256 len = siblings.length / 32;
        for (uint256 i = 0; i < len; i++) {
            bytes32 s = bytes32(
                Endian.reverse256(
                    uint256(bytes32(siblings[i * 32:(i + 1) * 32]))
                )
            );
            if (txIndex & 1 == 0) {
                ret = doubleSha(abi.encodePacked(ret, s));
            } else {
                ret = doubleSha(abi.encodePacked(s, ret));
            }
            txIndex = txIndex >> 1;
        }
        return ret;
    }

    /**
     * @dev Computes the ubiquitious Bitcoin SHA256(SHA256(x))
     */
    function doubleSha(bytes memory buf) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(sha256(buf)));
    }

    /**
     * @dev Recomputes the transaction ID for a raw transaction.
     */
    function getTxID(
        bytes calldata rawTransaction
    ) public pure returns (bytes32) {
        bytes32 ret = doubleSha(rawTransaction);
        return bytes32(Endian.reverse256(uint256(ret)));
    }

    /**
     * @dev Parses a HASH-SERIALIZED Bitcoin transaction.
     *      This means no flags and no segwit witnesses.
     */
    function parseBitcoinTx(
        bytes calldata rawTx
    ) public pure returns (BitcoinTx memory ret) {
        ret.version = Endian.reverse32(uint32(bytes4(rawTx[0:4])));
        if (ret.version < 1 || ret.version > 2) {
            return ret; // invalid version
        }

        // Read transaction inputs
        uint256 offset = 4;
        uint256 nInputs;
        (nInputs, offset) = readVarInt(rawTx, offset);
        ret.inputs = new BitcoinTxIn[](nInputs);
        for (uint256 i = 0; i < nInputs; i++) {
            BitcoinTxIn memory txIn;
            txIn.prevTxID = Endian.reverse256(
                uint256(bytes32(rawTx[offset:offset + 32]))
            );
            offset += 32;
            txIn.prevTxIndex = Endian.reverse32(
                uint32(bytes4(rawTx[offset:offset + 4]))
            );
            offset += 4;
            uint256 nInScriptBytes;
            (nInScriptBytes, offset) = readVarInt(rawTx, offset);
            require(nInScriptBytes <= 34, "Scripts over 34 bytes unsupported");
            txIn.scriptLen = uint32(nInScriptBytes);
            txIn.script = bytes32(rawTx[offset:offset + nInScriptBytes]);
            offset += nInScriptBytes;
            txIn.seqNo = Endian.reverse32(
                uint32(bytes4(rawTx[offset:offset + 4]))
            );
            offset += 4;
            ret.inputs[i] = txIn;
        }

        // Read transaction outputs
        uint256 nOutputs;
        (nOutputs, offset) = readVarInt(rawTx, offset);
        ret.outputs = new BitcoinTxOut[](nOutputs);
        for (uint256 i = 0; i < nOutputs; i++) {
            BitcoinTxOut memory txOut;
            txOut.valueSats = Endian.reverse64(
                uint64(bytes8(rawTx[offset:offset + 8]))
            );
            offset += 8;
            uint256 nOutScriptBytes;
            (nOutScriptBytes, offset) = readVarInt(rawTx, offset);
            require(nOutScriptBytes <= 34, "Scripts over 34 bytes unsupported");
            txOut.scriptLen = uint32(nOutScriptBytes);
            txOut.script = rawTx[offset:offset + nOutScriptBytes];
            offset += nOutScriptBytes;
            ret.outputs[i] = txOut;
        }

        // Finally, read locktime, the last four bytes in the tx.
        ret.locktime = Endian.reverse32(
            uint32(bytes4(rawTx[offset:offset + 4]))
        );
        offset += 4;
        if (offset != rawTx.length) {
            return ret; // Extra data at end of transaction.
        }

        // Parsing complete, sanity checks passed, return success.
        ret.validFormat = true;
        return ret;
    }

    /** Reads a Bitcoin-serialized varint = a u256 serialized in 1-9 bytes. */
    function readVarInt(
        bytes calldata buf,
        uint256 offset
    ) public pure returns (uint256 val, uint256 newOffset) {
        uint8 pivot = uint8(buf[offset]);
        if (pivot < 0xfd) {
            val = pivot;
            newOffset = offset + 1;
        } else if (pivot == 0xfd) {
            val = Endian.reverse16(uint16(bytes2(buf[offset + 1:offset + 3])));
            newOffset = offset + 3;
        } else if (pivot == 0xfe) {
            val = Endian.reverse32(uint32(bytes4(buf[offset + 1:offset + 5])));
            newOffset = offset + 5;
        } else {
            // pivot == 0xff
            val = Endian.reverse64(uint64(bytes8(buf[offset + 1:offset + 9])));
            newOffset = offset + 9;
        }
    }

    /**
     * @dev Verifies that `script` is a standard P2WSH (pay to witness script hash) tx.
     * @return result The recipient script hash, or 0 if verification failed.
     */
    function getP2WSH(
        uint256 scriptLen,
        bytes memory script
    ) internal pure returns (bytes32 result) {
        if (scriptLen != 34) {
            return 0;
        }
        // index 0: Witness version 0
        // index 1: OP_PUSHBYTES_32
        if (script[0] != 0x00 || script[1] != 0x20) {
            return 0;
        }

        assembly {
            // add(data, 32) skip script length
            // jump to index 2
            result := mload(add(add(script, 32), 2))
        }
    }

    /**
     * @dev Extracts an Ethereum address from a standard OP_RETURN script.
     * Expected format: OP_RETURN OP_PUSHBYTES_20 <20-byte-address>
     * @return result The extracted address, or address(0) if verification failed.
     */
    function getAddressFromOpReturn(
        uint256 scriptLen,
        bytes memory script
    ) internal pure returns (address result) {
        // OP_RETURN with 20-byte address: 1 + 1 + 20 = 22 bytes
        if (scriptLen != 22) {
            return address(0);
        }

        // index 0: OP_RETURN (0x6a)
        // index 1: OP_PUSHBYTES_20 (0x14)
        if (script[0] != 0x6a || script[1] != 0x14) {
            return address(0);
        }

        // Extract 20-byte address starting from index 2
        assembly {
            // Load 32 bytes from script starting at offset 2
            // The address is in the lower 20 bytes
            let addressData := mload(add(add(script, 32), 2))
            // Shift right to get only the address bytes (160 bits = 20 bytes)
            result := shr(96, addressData)
        }
    }

    /**
     * @dev Verifies that `script` is a standard OP_RETURN script with 32-byte data, and extracts the data.
     * @return result The data, or 0 if verification failed.
     */
    function getOpReturnScriptData(
        uint256 scriptLen,
        bytes memory script
    ) internal pure returns (bytes32 result) {
        if (scriptLen != 34) {
            return 0;
        }

        // index 0: OP_RETURN
        // index 1: OP_PUSHBYTES_32
        if (script[0] != 0x6a || script[1] != 0x20) {
            return 0;
        }

        assembly {
            result := mload(add(add(script, 32), 2))
        }
    }

    /**
     * @dev Creates a standard OP_RETURN script for testing purposes.
     * @param targetAddress The Ethereum address to embed in the OP_RETURN.
     * @return script The resulting OP_RETURN script bytes.
     */
    function createOpReturnScript(
        address targetAddress
    ) internal pure returns (bytes memory script) {
        script = new bytes(22);
        script[0] = 0x6a; // OP_RETURN
        script[1] = 0x14; // OP_PUSHBYTES_20

        // Copy address bytes
        assembly {
            mstore(add(script, 34), shl(96, targetAddress))
        }
    }
}
