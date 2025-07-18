// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @notice Tracks Bitcoin. Provides block hashes.
 */
interface IBtcMirror {
    /**
     * @notice Returns the Bitcoin block hash at a specific height.
     */
    function getBlockHash(uint256 number) external view returns (bytes32);

    /**
     * @notice Returns the height of the latest block (tip of the chain).
     */
    function getLatestBlockHeight() external view returns (uint256);

    /**
     * @notice Returns the timestamp of the lastest block, as Unix seconds.
     */
    function getLatestBlockTime() external view returns (uint256);

    /**
     * @notice Submits a new Bitcoin chain segment (80-byte headers) s
     */
    function submit_uncheck(uint256 blockHeight, bytes calldata blockHeaders, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @notice Challenges a previously submitted block by proving it's invalid, and submit the correct chain.
     */
    function challenge(
        uint256 wrong_idx,
        bytes calldata wrongBlockHeaders,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 blockHeight,
        bytes calldata blockHeaders
    ) external;
}
