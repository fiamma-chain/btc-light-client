// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Endian.sol";

contract EndianTest is Test {
    function test32() public pure {
        uint32 input = 0x12345678;
        assertEq(Endian.reverse32(input), 0x78563412);
    }

    function test256() public pure {
        uint256 input = 0x00112233445566778899aabbccddeeff00000000000000000123456789abcdef;
        assertEq(Endian.reverse256(input), 0xefcdab89674523010000000000000000ffeeddccbbaa99887766554433221100);
    }
}
