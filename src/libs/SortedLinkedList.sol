// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

struct LinkedList {
    uint256 count;
    mapping(bytes32 => bytes32) next;
}

library SortedLinkedList {
    error ValueInList();
    error ValueNotInList();
    error InvalidPreviousValue();
    error InvalidValue();

    function initialize(LinkedList storage list) internal {
        // Initialize the starting point of the list with the max value
        // We need this to ensure our value checks are valid when adding
        // a value to the end of the list.
        list.next[bytes32(0)] = bytes32(type(uint256).max);
    }

    function contains(LinkedList storage list, bytes32 value) internal view returns (bool) {
        return list.next[value] != bytes32(0);
    }

    function add(LinkedList storage list, bytes32 previous, bytes32 value) internal {
        // Check that the value is not already if the list
        if (contains(list, value)) revert ValueInList();

        // Check that the previous value is in the list
        if (!contains(list, previous)) revert InvalidPreviousValue();

        // Get the next value
        bytes32 next = list.next[previous];

        // The list is sorted smallest to largest.
        // Therefore, we need previous < value < next
        if (previous >= value || value >= next) revert InvalidValue();

        // Insert the value
        list.next[previous] = value;
        list.next[value] = next;

        // Increment the number of values in the list
        list.count++;
    }

    function remove(LinkedList storage list, bytes32 previous, bytes32 value) internal {
        // Check that the value is in the list
        if (!contains(list, value)) revert ValueNotInList();

        // Check that the previous value points to the value
        if (list.next[previous] != value) revert InvalidPreviousValue();

        // Delete the value by removing it from the link chain
        list.next[previous] = list.next[value];

        // Decrement the count
        list.count--;
    }
}
