// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BtcTxProof.sol";
import "./IBtcMirror.sol";

/** @notice Verifies Bitcoin transaction proofs. */
interface IBtcTxVerifier {
    /**
     * @notice Verifies that the a transaction cleared, paying a given amount to
     *         a given address. Specifically, verifies a proof that the tx was
     *         in block N, and that block N has at least M confirmations.
     *         Also verifies OP_RETURN output contains the expected recipient address.
     */
    function verifyPayment(
        uint256 minConfirmations,
        uint256 blockNum,
        BtcTxProof calldata inclusionProof,
        uint256 txOutIx,
        bytes32 destScriptHash,
        uint256 amountSats,
        address to
    ) external view returns (bool);

    /** @notice Returns the underlying mirror associated with this verifier. */
    function mirror() external view returns (IBtcMirror);
}
