// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./interfaces/IBtcMirror.sol";
import "./interfaces/IBtcTxVerifier.sol";
import "./BtcProofUtils.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

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
// BtcVerifier implements a merkle proof that a Bitcoin payment succeeded. It
// uses BtcMirror as a source of truth for which Bitcoin block hashes are in the
// canonical chain.
contract BtcTxVerifier is OwnableUpgradeable, IBtcTxVerifier {
    IBtcMirror public mirror;

    /// @dev Custom errors
    error InvalidOwnerAddress();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _mirror) external initializer {
        if (_owner == address(0)) revert InvalidOwnerAddress();

        __Ownable_init(_owner);
        mirror = IBtcMirror(_mirror);
    }

    function verifyPayment(
        uint256 _minConfirmations,
        uint256 blockNum,
        BtcTxProof calldata inclusionProof,
        uint256 txOutIx,
        bytes32 destScriptHash,
        uint256 amountSats,
        bool checkOpReturn,
        uint256 opReturnOutIx,
        bytes32 opReturnData
    ) external view returns (bool) {
        bytes32 blockHash = mirror.getBlockHash(blockNum);
        return BtcProofUtils.validatePayment(
            blockHash, inclusionProof, txOutIx, destScriptHash, amountSats, checkOpReturn, opReturnOutIx, opReturnData
        );
    }

    function verifyInclusion(uint256 minConfirmations, uint256 blockNum, TxInclusionProof calldata inclusionProof)
        external
        view
        returns (bool)
    {
        checkHeight(blockNum, minConfirmations);

        bytes32 blockHash = mirror.getBlockHash(blockNum);
        return BtcProofUtils.validateInclusion(blockHash, inclusionProof);
    }

    function checkHeight(uint256 blockNum, uint256 minConfirmations) internal view {
        uint256 mirrorHeight = mirror.getLatestBlockHeight();
        require(mirrorHeight >= blockNum, "Bitcoin Mirror doesn't have that block yet");
        require(mirrorHeight + 1 >= minConfirmations + blockNum, "Not enough Bitcoin block confirmations");
    }

    // reserved storage space to allow for layout changes in the future
    uint256[50] private __gap;
}
