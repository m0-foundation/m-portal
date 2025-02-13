// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { LinkedList, SortedLinkedList, START } from "./libs/SortedLinkedList.sol";

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

    address public immutable registrar;
    mapping(bytes32 => LinkedList) public lists;
    mapping(bytes32 => bytes32) public roots;

    /* ========== CONSTRUCTOR ========== */

    constructor(address registrar_) {
        registrar = registrar_;
    }

    /* ========== MANAGE LISTS ========== */

    function newList(bytes32 list) external {
        LinkedList storage ll = lists[list];

        // Check that the list is not already initialized
        if (_listExists(list)) revert ListAlreadyExists();

        // Initialize the new list
        ll.initialize();
    }

    function addToList(bytes32 list, bytes32 value, bytes32 hint) external {
        // Check that the list exists
        if (!_listExists(list)) revert InvalidList();

        // Check that the value is set on the list in the registrar
        if (!_isSetOnRegistrar(list, value)) revert InvalidAdd();

        // We hash the value before adding to the list so that the leaves
        // are sorted correctly for constructing the merkle tree
        bytes32 leaf = keccak256(abi.encodePacked(value));

        // Check that the value is not already in the list
        LinkedList storage ll = lists[list];
        if (ll.contains(leaf)) revert ValueInList();

        // Add the leaf to the list
        ll.add(hint, leaf);
    }

    function removeFromList(bytes32 list, bytes32 value, bytes32 hint) external {
        // Check that the list exists
        if (!_listExists(list)) revert InvalidList();

        // Check that the value is not set on the list in the registrar
        if (_isSetOnRegistrar(list, value)) revert InvalidRemove();

        // We hash the value before adding to the list so that the leaves are
        // sorted correctly for constructing the merkle tree
        bytes32 leaf = keccak256(abi.encodePacked(value));

        // Check that the value is in the list
        LinkedList storage ll = lists[list];
        if (!ll.contains(leaf)) revert ValueNotInList();

        // Add the leaf to the list
        ll.remove(hint, leaf);
    }

    /* ========== MERKLE TREE ========== */

    function updateRoot(bytes32 list) external {
        // Check that the list exists
        if (!_listExists(list)) revert InvalidList();

        // Build the tree and store the root
        roots[list] = _buildTree(list);

        // Emit event?
    }

    /* ========== HELPERS ========== */

    function _buildTree(bytes32 list) internal returns (bytes32) {
        LinkedList storage ll = lists[list];

        // Get size of the list
        // If odd, add one more
        uint256 count = ll.count;
        uint256 len = count % 2 == 0 ? count : count + 1;

        // Put the list into an array
        bytes32[] memory tree = new bytes32[](len);

        tree[0] = ll.next[START];
        for (uint256 i = 1; i < count; i++) {
            tree[i] = ll.next[tree[i - 1]];
        }

        // Add the last value again if the count was odd
        if (len > count) {
            tree[count] = tree[count - 1];
        }

        // Iterate through the tree, hashing the values
        while (len > 1) {
            tree = _hashLevel(tree);
            len = tree.length;
        }

        // When the tree is length 1, then we have the root
        return tree[0];
    }

    // general idea based on Murky
    function _hashLevel(bytes32[] memory currentLevel) internal returns (bytes32[] memory nextLevel) {
        // Get the length of the level
        uint256 len = currentLevel.length;

        // If the length is odd, we need to add one to the length of the resulting level
        bool lenOdd = len % 2 == 0;
        uint256 nextLen = lenOdd ? len / 2 : len / 2 + 1;
        nextLevel = new bytes32[](nextLen);

        // Iterate through the current level and construct the next level
        for (uint256 i; i < len - 1; i = i + 2) {
            bytes32 one = currentLevel[i];
            bytes32 two = currentLevel[i + 1];

            bytes32 h;
            if (one < two) {
                h = keccak256(abi.encodePacked(one, two));
            } else {
                h = keccak256(abi.encodePacked(two, one));
            }

            nextLevel[i / 2] = h;
        }

        // if the length of the current level is odd, we hash the final node
        // with itself
        if (lenOdd) {
            nextLevel[nextLen - 1] = keccak256(abi.encodePacked(currentLevel[len - 1], currentLevel[len - 1]));
        }
    }

    function _isSetOnRegistrar(bytes32 list, bytes32 value) internal returns (bool) {
        bytes32 key = keccak256(abi.encode(list, value));

        bytes32 isSet = IRegistrarLike(registrar).get(key);

        // Note: the idea is that these values would be set to 0 or 1,
        // but they don't necessarily have to be, so we check if not 0
        return isSet != bytes32(0);
    }

    function _listExists(bytes32 list) internal returns (bool) {
        // If the list exists it will be initialized with the START node pointing to non-zero node
        return lists[list].next[START] != bytes32(0);
    }
}
