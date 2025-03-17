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

    /* ========== EVENTS ========== */

    event RootUpdated(bytes32 indexed list, bytes32 root);

    /* ========== STATE ========== */

    uint8 internal constant ZERO_BIT = 0;
    uint8 internal constant ONE_BIT = 1;
    address public immutable registrar;
    bytes32 internal constant ZERO_WORD = bytes32(0);
    mapping(bytes32 => LinkedList) internal _lists;
    mapping(bytes32 => bytes32) internal _roots;

    /* ========== CONSTRUCTOR ========== */

    constructor(address registrar_) {
        registrar = registrar_;
    }

    /* ========== MANAGE LISTS ========== */

    function addToList(bytes32 list, bytes32 before, bytes32 value) external {
        // Check that the value is set on the list in the registrar
        if (!_isSetOnRegistrar(list, value)) revert InvalidAdd();

        // Initialize the list, if needed
        LinkedList storage sortedList = _lists[list];
        if (sortedList.count == 0) sortedList.initialize();

        // Add the value to the list
        // If the value is already in the list, it will revert
        // If the before value is not immediately before where the value should be inserted, it will revert
        sortedList.add(before, value);
    }

    function removeFromList(bytes32 list, bytes32 before, bytes32 value) external {
        // Check that the value is not set on the list in the registrar
        if (_isSetOnRegistrar(list, value)) revert InvalidRemove();

        // Remove the leaf from the list
        // If the value is not in the list, it will revert
        // If the before value is not immediately before the value, it will revert
        _lists[list].remove(before, value);
    }

    /* ========== MERKLE TREE ========== */

    function updateRoot(bytes32 list) external {
        LinkedList storage sortedList = _lists[list];
        uint256 leafCount = _lists[list].count;

        // If the list has no members, then the root is the zero value
        if (leafCount == 0) {
            // Set the root to the hash of the zero value so exclusion proofs
            // can be performed against it using the zero value as the neighbor
            _roots[list] = keccak256(abi.encodePacked(ZERO_BIT, ZERO_WORD));
            return;
        }

        // If the list has only one member, then the root is the hash of the leaf
        if (leafCount == 1) {
            _roots[list] = keccak256(abi.encodePacked(ZERO_BIT, sortedList.next[ZERO_WORD]));
            return;
        }

        // Build the tree

        // For the first layer, we need to first construct the leaves
        // and then hash neighboring leaves together
        // We do this at the same time to reduce the total memory required by a factor of 2

        // Calculate the size of array required
        uint256 len = (leafCount + 1) / 2; // this has the same effect as rounding up the division and is more efficient

        // Create the array
        bytes32[] memory tree = new bytes32[](len);

        // Create the leaves, then has with the neighbor to populate the first level of the tree
        bytes32 previous = ZERO_WORD;
        for (uint256 i = 0; i < leafCount - 1; i = i + 2) {
            bytes32 one = sortedList.next[previous];
            bytes32 two = sortedList.next[one];

            previous = two;

            // Hash to get leaves
            one = keccak256(abi.encodePacked(ZERO_BIT, one));
            two = keccak256(abi.encodePacked(ZERO_BIT, two));

            // Hash neighboring leaves to construct the first level of the tree
            tree[i / 2] = keccak256(abi.encodePacked(ONE_BIT, one, two));
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
            // Hash neighboring nodes
            for (uint256 i = 0; i < len - 1; i = i + 2) {
                bytes32 one = tree[i];
                bytes32 two = tree[i + 1];

                // Hash the neighbors to get the next level
                tree[i / 2] = keccak256(abi.encodePacked(ONE_BIT, one, two));
            }

            // Calculate the length of the next level
            uint256 nextLen = (len + 1) / 2;

            // If the length of the current level is odd, we hash the final node with itself
            if (len % 2 != 0) {
                tree[nextLen - 1] = keccak256(abi.encodePacked(ONE_BIT, tree[len - 1], tree[len - 1]));
            }

            // Update the length of the tree
            len = nextLen;
        }

        // The tree's root is now at the first index of the array
        _roots[list] = tree[0];

        // Emit event
        emit RootUpdated(list, _roots[list]);
    }

    /* ========== VIEWS ========== */

    function getNext(bytes32 list, bytes32 value) external view returns (bytes32) {
        return _lists[list].next[value];
    }

    function getLen(bytes32 list) external view returns (uint256) {
        return _lists[list].count;
    }

    function getList(bytes32 list) external view returns (bytes32[] memory) {
        LinkedList storage sortedList = _lists[list];
        bytes32[] memory result = new bytes32[](sortedList.count);

        bytes32 current = sortedList.next[ZERO_WORD];
        for (uint256 i = 0; i < sortedList.count; i++) {
            result[i] = current;
            current = sortedList.next[current];
        }

        return result;
    }

    function contains(bytes32 list, bytes32 value) external view returns (bool) {
        return _lists[list].contains(value);
    }

    function getRoot(bytes32 list) external view returns (bytes32) {
        return _roots[list];
    }

    /* ========== HELPERS ========== */

    function _isSetOnRegistrar(bytes32 list, bytes32 value) internal view returns (bool) {
        bytes32 key = keccak256(abi.encodePacked(list, value));

        bytes32 isSet = IRegistrarLike(registrar).get(key);

        // Note: the idea is that these values would be set to 0 or 1,
        // but they don't necessarily have to be, so we check if not 0
        return isSet != ZERO_WORD;
    }
}
