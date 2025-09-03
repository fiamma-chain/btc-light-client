// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Endian.sol";
import "./interfaces/IBtcMirror.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

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
// BtcMirror lets you prove that a Bitcoin transaction executed, on Ethereum. It
// does this by running an on-chain light client.
//
// Anyone can submit block headers to BtcMirror. The contract verifies
// proof-of-work, keeping only the longest chain it has seen. As long as 50% of
// Bitcoin hash power is honest and at least one person is running the submitter
// script, the BtcMirror contract always reports the current canonical Bitcoin
// chain.
contract BtcMirror is IBtcMirror, OwnableUpgradeable {
    /**
     * @notice Emitted whenever the contract accepts a new heaviest chain.
     */
    event NewTip(uint256 blockHeight, uint256 blockTime, bytes32 blockHash);

    /**
     * @notice Emitted only after a difficulty retarget, when the contract
     *         accepts a new heaviest chain with updated difficulty.
     */
    event NewTotalDifficultySinceRetarget(uint256 blockHeight, uint256 totalDifficulty, uint32 newDifficultyBits);

    /**
     * @notice Emitted when we reorg out a portion of the chain.
     */
    event Reorg(uint256 count, bytes32 oldTip, bytes32 newTip);

    uint256 private latestBlockHeight;

    uint256 private latestBlockTime;

    mapping(uint256 => bytes32) private blockHeightToHash;

    /**
     * @notice Difficulty targets in each retargeting period.
     */
    mapping(uint256 => uint256) public periodToTarget;

    /**
     * @notice Whether we're tracking testnet or mainnet Bitcoin.
     */
    bool public isTestnet;

    /**
     * @notice Constructor for the logic contract
     * @dev Disables initializers to prevent direct initialization of the logic contract.
     *      This is a security measure for upgradeable contracts deployed behind proxies.
     *      The logic contract should only be initialized through the proxy.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     *          Tracks Bitcoin starting from a given block. The isTestnet
     *          argument is necessary because the Bitcoin testnet does not
     *          respect the difficulty rules, so we disable block difficulty
     *          checks in order to track it.
     */
    function initialize(
        address _admin,
        uint256 _blockHeight,
        bytes32 _blockHash,
        uint256 _blockTime,
        uint256 _expectedTarget,
        bool _isTestnet
    ) external initializer {
        require(_admin != address(0), "Invalid admin address");
        __Ownable_init(_admin);

        blockHeightToHash[_blockHeight] = _blockHash;
        latestBlockHeight = _blockHeight;
        latestBlockTime = _blockTime;
        periodToTarget[_blockHeight / 2016] = _expectedTarget;
        isTestnet = _isTestnet;
    }

    /**
     * @notice Returns the Bitcoin block hash at a specific height.
     */
    function getBlockHash(uint256 number) public view returns (bytes32) {
        return blockHeightToHash[number];
    }

    /**
     * @notice Returns the height of the current chain tip.
     */
    function getLatestBlockHeight() public view returns (uint256) {
        return latestBlockHeight;
    }

    /**
     * @notice Returns the timestamp of the current chain tip.
     */
    function getLatestBlockTime() public view returns (uint256) {
        return latestBlockTime;
    }

    /**
     * @notice Returns latest block height and specific block hash in one call
     * @dev This is optimized for LayerZero cross-chain reads to reduce call count
     * @param blockNumber The specific block number to get hash for
     * @return latestHeight The latest block height
     * @return requestedBlockNumber The requested block number
     * @return blockHash The hash of the requested block
     */
    function getLatestHeightAndBlockHash(uint256 blockNumber)
        public
        view
        returns (uint256 latestHeight, uint256 requestedBlockNumber, bytes32 blockHash)
    {
        return (latestBlockHeight, blockNumber, blockHeightToHash[blockNumber]);
    }
    /**
     * @notice Allows the owner to submit a new Bitcoin chain segment.
     *         This function is only callable by the owner.
     * @dev This function is used to submit new blocks to the BtcMirror contract.
     *      It verifies the block headers and updates the state accordingly.
     */

    function submit_uncheck(uint256 blockHeight, bytes calldata blockHeaders, uint8 v, bytes32 r, bytes32 s)
        external
        onlyOwner
    {
        bytes32 hash = keccak256(abi.encode(blockHeight, blockHeaders));
        address expected_addr = ecrecover(hash, v, r, s);
        require(expected_addr == msg.sender, "Invalid signature");

        uint256 numHeaders = blockHeaders.length / 80;
        require(numHeaders * 80 == blockHeaders.length, "wrong header length");
        require(numHeaders > 0, "must submit at least one block");

        uint256 newHeight = blockHeight + numHeaders - 1;
        for (uint256 i = 0; i < numHeaders; i++) {
            bytes calldata blockHeader = blockHeaders[80 * i:80 * (i + 1)];
            uint256 blockNum = blockHeight + i;
            uint256 blockHashNum = Endian.reverse256(uint256(sha256(abi.encode(sha256(blockHeader)))));
            blockHeightToHash[blockNum] = bytes32(blockHashNum);

            if (blockNum % 2016 == 0) {
                bytes32 bits = bytes32(blockHeader[72:76]);
                uint256 target = getTarget(bits);
                periodToTarget[blockNum / 2016] = target;
            }
        }

        latestBlockHeight = newHeight;
        latestBlockTime =
            Endian.reverse32(uint32(bytes4(blockHeaders[blockHeaders.length - 12:blockHeaders.length - 8])));

        bytes32 newTip = getBlockHash(newHeight);
        emit NewTip(newHeight, latestBlockTime, newTip);
    }

    /**
     * @notice Validates a Bitcoin block header
     * @param header 80-byte block header data
     * @param blockHeight block height
     * @return true if the block header is valid, false otherwise
     */
    function validateHeader(bytes calldata header, uint256 blockHeight) public view returns (bool) {
        require(header.length == 80, "wrong header length");
        require(blockHeight > 0, "The genesis block cannot be validated");

        // 1. Validate block hash calculation
        uint256 blockHashNum = Endian.reverse256(uint256(sha256(abi.encode(sha256(header)))));

        // 2. Validate previous block hash
        bytes32 prevHash = bytes32(Endian.reverse256(uint256(bytes32(header[4:36]))));

        // Check if previous block exists
        if (blockHeightToHash[blockHeight - 1] == bytes32(0)) {
            return false;
        }

        // Check if previous block hash matches
        if (prevHash != blockHeightToHash[blockHeight - 1]) {
            return false;
        }

        // 3. Validate proof of work and difficulty target
        bytes32 bits = bytes32(header[72:76]);
        uint256 target = getTarget(bits);

        // 4. Validate difficulty target
        uint256 period = blockHeight / 2016;
        if (blockHeight % 2016 == 0) {
            // For difficulty adjustment blocks, validate the adjustment is legal
            uint256 lastTarget = periodToTarget[period - 1];
            if (!isTestnet && target >> 2 >= lastTarget) {
                // Difficulty decreased by more than 75%
                return false;
            }
        } else if (!isTestnet && target != periodToTarget[period]) {
            // For non-adjustment blocks, validate difficulty matches current period
            return false;
        }

        // 5. Validate block hash meets difficulty requirement
        if (blockHashNum >= target) {
            return false;
        }

        // 6. Validate version number
        uint32 version = Endian.reverse32(uint32(bytes4(header[0:4])));
        if (version < 2) {
            return false;
        }

        // 7. Validate Merkle Root
        bytes32 merkleRoot = bytes32(Endian.reverse256(uint256(bytes32(header[36:68]))));
        if (merkleRoot == bytes32(0)) {
            return false;
        }

        return true;
    }

    /**
     * @notice Challenges a previously submitted block by proving it's invalid, and submit the correct chain.
     * @dev This function allows anyone to challenge a block by providing evidence that it violates Bitcoin consensus rules.
     *      The challenger must provide:
     *      1. The owner's signature to prevent spam
     *      2. The invalid block headers
     *      3. The index of the specific invalid block
     *      4. A valid alternative chain
     *      If the challenge is successful (i.e., the block is proven invalid), the alternative chain is accepted.
     *
     * @param wrong_idx Index of the invalid block in the wrongBlockHeaders array
     * @param wrongBlockHeaders Array of block headers containing the invalid block
     * @param v Recovery byte of the owner's signature
     * @param r R component of the owner's signature
     * @param s S component of the owner's signature
     * @param blockHeight Starting height of the alternative chain
     * @param blockHeaders Alternative valid chain to replace the invalid one
     *
     * @custom:security-note The owner's signature is required to prevent DoS attacks through excessive challenges
     */
    function challenge(
        uint256 wrong_idx,
        bytes calldata wrongBlockHeaders,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 blockHeight,
        bytes calldata blockHeaders
    ) external {
        address owner = owner();
        bytes32 hash = keccak256(abi.encode(blockHeight, wrongBlockHeaders));
        address expected_addr = ecrecover(hash, v, r, s);
        require(expected_addr == owner, "Challenger use wrong signature");
        require(blockHeight > 0, "The genesis block cannot be challenged");

        uint256 numWrongHeaders = wrongBlockHeaders.length / 80;
        require(numWrongHeaders * 80 == wrongBlockHeaders.length, "wrong header length");
        require(numWrongHeaders > 0, "must submit at least one block");

        bytes calldata wrongHeader = wrongBlockHeaders[80 * wrong_idx:80 * (wrong_idx + 1)];
        uint256 wrongBlockHeight = blockHeight + wrong_idx;

        // Validate the challenged block header
        bool isValid = validateHeader(wrongHeader, wrongBlockHeight);
        require(!isValid, "The challenged block appears to be valid");

        // submit the correct chain
        submit(blockHeight, blockHeaders);
    }

    /**
     * Submits a new Bitcoin chain segment. Must be heavier (not necessarily
     * longer) than the chain rooted at getBlockHash(getLatestBlockHeight()).
     */
    function submit(uint256 blockHeight, bytes calldata blockHeaders) private {
        uint256 numHeaders = blockHeaders.length / 80;
        require(numHeaders * 80 == blockHeaders.length, "wrong header length");
        require(numHeaders > 0, "must submit at least one block");

        // sanity check: the new chain must not end in a past difficulty period
        // (BtcMirror does not support a 2-week reorg)
        uint256 oldPeriod = latestBlockHeight / 2016;
        uint256 newHeight = blockHeight + numHeaders - 1;
        uint256 newPeriod = newHeight / 2016;
        require(newPeriod >= oldPeriod, "old difficulty period");

        // if we crossed a retarget, do extra math to compare chain weight
        uint256 parentPeriod = (blockHeight - 1) / 2016;
        uint256 oldWork = 0;
        if (newPeriod > parentPeriod) {
            assert(newPeriod == parentPeriod + 1);
            // the submitted chain segment contains a difficulty retarget.
            if (newPeriod == oldPeriod) {
                // the old canonical chain is past the retarget
                // we cannot compare length, we must compare total work
                oldWork = getWorkInPeriod(oldPeriod, latestBlockHeight);
            } else {
                // the old canonical chain is before the retarget
                assert(oldPeriod == parentPeriod);
            }
        }

        // verify and store each block
        bytes32 oldTip = getBlockHash(latestBlockHeight);
        uint256 nReorg = 0;
        for (uint256 i = 0; i < numHeaders; i++) {
            uint256 blockNum = blockHeight + i;
            nReorg += submitBlock(blockNum, blockHeaders[80 * i:80 * (i + 1)]);
        }

        // check that we have a new heaviest chain
        if (newPeriod > parentPeriod) {
            // the submitted chain segment crosses into a new difficulty
            // period. this is happens once every ~2 weeks. check total work
            bytes calldata lastHeader = blockHeaders[80 * (numHeaders - 1):];
            uint32 newDifficultyBits = Endian.reverse32(uint32(bytes4(lastHeader[72:76])));

            uint256 newWork = getWorkInPeriod(newPeriod, newHeight);
            require(newWork > oldWork, "insufficient total difficulty");

            // erase any block hashes above newHeight, now invalidated.
            // (in case we just accepted a shorter, heavier chain.)
            for (uint256 i = newHeight + 1; i <= latestBlockHeight; i++) {
                blockHeightToHash[i] = 0;
            }

            emit NewTotalDifficultySinceRetarget(newHeight, newWork, newDifficultyBits);
        } else {
            // here we know what newPeriod == oldPeriod == parentPeriod
            // with identical per-block difficulty. just keep the longest chain.
            assert(newPeriod == oldPeriod);
            assert(newPeriod == parentPeriod);
            require(newHeight > latestBlockHeight, "insufficient chain length");
        }

        // record the new tip height and timestamp
        latestBlockHeight = newHeight;
        uint256 ixT = blockHeaders.length - 12;
        uint32 time = uint32(bytes4(blockHeaders[ixT:ixT + 4]));
        latestBlockTime = Endian.reverse32(time);

        // finally, log the new tip
        bytes32 newTip = getBlockHash(newHeight);
        emit NewTip(newHeight, latestBlockTime, newTip);
        if (nReorg > 0) {
            emit Reorg(nReorg, oldTip, newTip);
        }
    }

    function getWorkInPeriod(uint256 period, uint256 height) private view returns (uint256) {
        uint256 target = periodToTarget[period];
        uint256 workPerBlock = (2 ** 256 - 1) / target;

        uint256 numBlocks = height - (period * 2016) + 1;
        assert(numBlocks >= 1 && numBlocks <= 2016);

        return numBlocks * workPerBlock;
    }

    function submitBlock(uint256 blockHeight, bytes calldata blockHeader) private returns (uint256 numReorged) {
        // compute the block hash
        assert(blockHeader.length == 80);
        uint256 blockHashNum = Endian.reverse256(uint256(sha256(abi.encode(sha256(blockHeader)))));

        // optimistically save the block hash
        // we'll revert if the header turns out to be invalid
        bytes32 oldHash = blockHeightToHash[blockHeight];
        bytes32 newHash = bytes32(blockHashNum);
        if (oldHash != bytes32(0) && oldHash != newHash) {
            // if we're overwriting a non-zero block hash, that block is reorged
            numReorged = 1;
        }
        // this is the most expensive line. 20,000 gas to use a new storage slot
        blockHeightToHash[blockHeight] = newHash;

        // verify previous hash
        bytes32 prevHash = bytes32(Endian.reverse256(uint256(bytes32(blockHeader[4:36]))));
        require(prevHash == blockHeightToHash[blockHeight - 1], "bad parent");
        require(prevHash != bytes32(0), "parent block not yet submitted");

        // verify proof-of-work
        bytes32 bits = bytes32(blockHeader[72:76]);
        uint256 target = getTarget(bits);
        require(blockHashNum < target, "block hash above target");

        // support once-every-2016-blocks retargeting
        uint256 period = blockHeight / 2016;
        if (blockHeight % 2016 == 0) {
            // Bitcoin enforces a minimum difficulty of 25% of the previous
            // difficulty. Doing the full calculation here does not necessarily
            // add any security. We keep the heaviest chain, not the longest.
            uint256 lastTarget = periodToTarget[period - 1];
            // ignore difficulty update rules on testnet.
            // Bitcoin testnet has some clown hacks regarding difficulty, see
            // https://blog.lopp.net/the-block-storms-of-bitcoins-testnet/
            if (!isTestnet) {
                require(target >> 2 < lastTarget, "<25% difficulty retarget");
            }
            periodToTarget[period] = target;
        } else if (!isTestnet) {
            // verify difficulty
            require(target == periodToTarget[period], "wrong difficulty bits");
        }
    }

    function getTarget(bytes32 bits) public pure returns (uint256) {
        // Bitcoin represents difficulty using a custom floating-point big int
        // representation. the "difficulty bits" consist of an 8-bit exponent
        // and a 24-bit mantissa, which combine to generate a u256 target. the
        // block hash must be below the target.
        uint256 exp = uint8(bits[3]);
        uint256 mantissa = uint8(bits[2]);
        mantissa = (mantissa << 8) | uint8(bits[1]);
        mantissa = (mantissa << 8) | uint8(bits[0]);
        uint256 target = mantissa << (8 * (exp - 3));
        return target;
    }
}
