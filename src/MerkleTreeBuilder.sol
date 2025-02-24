// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { LinkedList, SortedLinkedList } from "./libs/SortedLinkedList.sol";

contract MerkleTreeBuilder {
    using SortedLinkedList for LinkedList;

    /* ========== ERRORS ========== */

    error ListAlreadyExists();
    error InvalidList();
    error InvalidAdd();
    error InvalidRemove();
    error NotInList();
    error ValueInList();
    error ValueNotInList();

    /* ========== STATE ========== */

    uint8 internal constant ZERO_BIT = 0;
    uint8 internal constant ONE_BIT = 1;
    address public immutable registrar;
    mapping(bytes32 => LinkedList) public lists;
    mapping(bytes32 => bytes32) public roots;

    /* ========== CONSTRUCTOR ========== */

    constructor(address registrar_) {
        registrar = registrar_;
    }

    /* ========== MANAGE LISTS ========== */

    function addToList(bytes32 list, bytes32 before, bytes32 value) external {
        // Check that the value is set on the list in the registrar
        if (!_isSetOnRegistrar(list, value)) revert InvalidAdd();

        // Add the value to the list
        lists[list].add(before, value);
    }

    function removeFromList(bytes32 list, bytes32 before, bytes32 value) external {
        // Check that the value is not set on the list in the registrar
        if (_isSetOnRegistrar(list, value)) revert InvalidRemove();

        // Remove the leaf from the list
        lists[list].remove(before, value);
    }

    /* ========== MERKLE TREE ========== */

    function updateRoot(bytes32 list) external {
        // If the list has no members, then the root is the zero value
        if (lists[list].count == 0) {
            roots[list] = bytes32(0);
            return;
        }

        // If the list has only one member, then the root is the hash of the member
        if (lists[list].count == 1) {
            roots[list] = keccak256(abi.encodePacked(ZERO_BIT, lists[list].next[bytes32(0)]));
            return;
        }

        // Build the tree

        // For the first layer, we need to first construct the leaves
        // and then hash neighboring leaves together
        // We do this at the same time to reduce the total memory required by a factor of 2

        // Calculate the size of array required
        // Reduce the count by a power of two and add one if the count is odd
        uint256 leafCount = lists[list].count;
        uint256 len = leafCount % 2 == 0 ? leafCount / 2 : leafCount / 2 + 1;

        // Create the array
        bytes32[] memory tree = new bytes32[](len);

        // Create the leaves, then has with the neighbor to populate the first level of the tree
        LinkedList storage sortedList = lists[list];
        bytes32 previous = sortedList.next[bytes32(0)];
        for (uint256 i = 0; i < leafCount - 1; i = i + 2) {
            bytes32 one = sortedList.next[previous];
            bytes32 two = sortedList.next[one];

            // Hash to get leaves
            one = keccak256(abi.encodePacked(ZERO_BIT, one));
            two = keccak256(abi.encodePacked(ZERO_BIT, two));

            // Hash neighboring leaves to construct the first level of the tree
            tree[i / 2] = keccak256(abi.encodePacked(ONE_BIT, one, two));
            previous = two;
        }

        // If the leaf count is odd, we have to populate the last node
        // We hash the last leaf with itself to avoid zero values in the tree
        if (leafCount % 2 != 0) {
            bytes32 one = keccak256(abi.encodePacked(ZERO_BIT, sortedList.next[previous]));
            tree[len - 1] = keccak256(abi.encodePacked(ONE_BIT, one, one));
        }

        // Now, we iteratively combine every 2 nodes until the length of the tree is 1
        // We overwrite values as we go to reuse memory that's already been allocated
        while (len > 1) {
            // Calculate the length of the next level
            uint256 nextLen = len % 2 == 0 ? len / 2 : len / 2 + 1;

            // Hash neighboring nodes
            for (uint256 i = 0; i < len - 1; i = i + 2) {
                bytes32 one = tree[i];
                bytes32 two = tree[i + 1];

                // Hash the neighbors to get the next level
                tree[i / 2] = keccak256(abi.encodePacked(ONE_BIT, one, two));
            }

            // If the length of the current level is odd, we hash the final node with itself
            if (nextLen % 2 != 0) {
                tree[nextLen - 1] = keccak256(abi.encodePacked(ONE_BIT, tree[len - 1], tree[len - 1]));
            }

            // Update the length of the tree
            len = nextLen;
        }

        // The tree's root is now at the first index of the array
        roots[list] = tree[0];

        // Emit event?
    }

    /* ========== HELPERS ========== */

    function _isSetOnRegistrar(bytes32 list, bytes32 value) internal view returns (bool) {
        bytes32 key = keccak256(abi.encode(list, value));

        bytes32 isSet = IRegistrarLike(registrar).get(key);

        // Note: the idea is that these values would be set to 0 or 1,
        // but they don't necessarily have to be, so we check if not 0
        return isSet != bytes32(0);
    }
}
