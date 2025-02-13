// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

struct LinkedList {
    uint256 count;
    mapping(bytes32 => bytes32) next;
}

bytes32 constant START = 0x0000000000000000000000000000000000000000000000000000000000000000;
bytes32 constant END = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

library SortedLinkedList {
    function initialize(LinkedList storage list) internal {
        // Set the next item for the start key to the end key
        list.next[START] = END;
    }

    function contains(LinkedList storage list, bytes32 value) internal returns (bool) {
        return list.next[value] != bytes32(0);
    }

    function add(LinkedList storage list, bytes32 hint, bytes32 value) internal {
        // Check that the value is not already if the list
        require(!contains(list, value), "Value already in list");

        // Check if the hint is in the list, if not, use the start value
        // This will always be true if no hint is provided or the hint is the START node
        bytes32 hint_ = contains(list, hint) ? hint : START;

        // The list is sorted smallest to largest, so the hint must be less than the value
        require(hint_ < value, "Invalid hint");

        // Find the slot to insert the value
        // If an optimal hint is provided, then this will be an O(1) operation
        bytes32 prev = hint;
        bytes32 next = list.next[prev];
        while (next < value) {
            prev = next;
            next = list.next[prev];
        }

        // Insert the value
        list.next[prev] = value;
        list.next[value] = next;

        // Increment the number of values in the list
        list.count++;
    }

    function remove(LinkedList storage list, bytes32 hint, bytes32 value) internal {
        // Check that the value is in the list
        require(contains(list, value), "Value not in list");

        // Check that the hint is in the list, if not, use the start value
        bytes32 hint_ = contains(list, hint) ? hint : START;

        // The list is sorted smallest to larget, so the hint must be less than the value
        // This will always be true if no hint is provided or the hint is the START node
        require(hint_ < value, "Invalid hint");

        // Find the value right before the value to be deleted
        // If an optimal hint is provided, then the hint will be the previous value
        bytes32 prev = hint_;
        while (list.next[prev] != value) {
            prev = list.next[prev];
        }

        // Delete the value by removing it from the link chain
        list.next[prev] = list.next[value];

        // Decrement the count
        list.count--;
    }
}
