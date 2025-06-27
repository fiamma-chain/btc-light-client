// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BtcTxProof.sol";
import "./IBtcMirror.sol";

/** @notice The type of script_pubkey used in the transaction. */
enum BitcoinScriptType {
    P2WSH,
    P2TR
}

/** @notice Verifies Bitcoin transaction proofs. */
interface IBtcTxVerifier {
    /**
     * @notice Verifies that the a transaction cleared, paying a given amount to
     *         a given address. Specifically, verifies a proof that the tx was
     *         in block N, and that block N has at least M confirmations.
     *
     *         Also verifies that if checkOpReturn is true, the transaction has an OP_RETURN output
     *         with the given data, and that the output is at the given index.
     */
    function verifyPayment(
        uint256 minConfirmations,
        uint256 blockNum,
        BtcTxProof calldata inclusionProof,
        uint256 txOutIx,
        bytes32 destScriptHash,
        BitcoinScriptType scriptType,
        uint256 amountSats,
        bool checkOpReturn,
        uint256 opReturnOutIx,
        bytes32 opReturnData
    ) external view returns (bool);

    /** @notice Returns the underlying mirror associated with this verifier. */
    function mirror() external view returns (IBtcMirror);
}
