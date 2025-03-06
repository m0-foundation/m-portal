// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

interface IMerkleTreeBuilder {
    function getRoot(bytes32 list) external view returns (bytes32);
}
