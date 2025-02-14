// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

struct LinkedList {
    uint256 count;
    mapping(bytes32 => bytes32) next;
}

library SortedLinkedList {
    function contains(LinkedList storage list, bytes32 value) internal view returns (bool) {
        return value == bytes32(0) || list.next[value] != bytes32(0);
    }

    function add(LinkedList storage list, bytes32 previous, bytes32 value) internal {
        // Check that the value is not already if the list
        require(!contains(list, value), "Value already in list");

        // Check that the previous value is in the list
        require(contains(list, previous), "Previous value not in list");

        // Get the next value
        bytes32 next = list.next[previous];

        // The list is sorted smallest to largest.
        // Therefore, we need previous < value < next
        require(previous < value && value < next, "Invalid value");

        // Insert the value
        list.next[previous] = value;
        list.next[value] = next;

        // Increment the number of values in the list
        list.count++;
    }

    function remove(LinkedList storage list, bytes32 previous, bytes32 value) internal {
        // Check that the value is in the list
        require(contains(list, value), "Value not in list");

        // Check that the previous value points to the value
        require(list.next[previous] == value, "Previous value invalid");

        // Get the next value
        bytes32 next = list.next[value];

        // The list is sorted smallest to largest.
        // Therefore, we need previous < value < next
        require(previous < value && value < next, "Invalid value");

        // Delete the value by removing it from the link chain
        list.next[previous] = list.next[value];

        // Decrement the count
        list.count--;
    }
}
