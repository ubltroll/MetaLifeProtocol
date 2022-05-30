// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

contract RecordPacker {
    function packRecord (address target, uint96 index) internal pure returns(uint256 record) {
        record += uint256(uint256(uint160(target)) << 96);
        record += uint256(index);
    }

    function resovleRecord (uint256 record) internal pure returns(address target, uint96 index) {
        target = address(uint160(record >> 96));
        index = uint96(record);
    }
}
