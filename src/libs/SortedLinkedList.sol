// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

struct LinkedList {
    uint256 count;
    mapping(bytes32 => bytes32) next;
}

library SortedLinkedList {
    error AlreadyInitialized();
    error ValueInList();
    error ValueNotInList();
    error InvalidPreviousValue();
    error InvalidValue();

    bytes32 internal constant ZERO = bytes32(0);
    bytes32 internal constant MAX = bytes32(type(uint256).max);

    function initialize(LinkedList storage list) internal {
        // Prevent re-initializing the list if values are currently in it
        // Re-initializing an empty list does not matter
        if (list.count > 0) revert AlreadyInitialized();

        // Initialize the starting point of the list with the max value
        // We need this to ensure our value checks are valid when adding
        // a value to the end of the list.
        list.next[ZERO] = MAX;
    }

    function contains(LinkedList storage list, bytes32 value) internal view returns (bool) {
        return list.next[value] != ZERO && value != ZERO;
    }

    function add(LinkedList storage list, bytes32 previous, bytes32 value) internal {
        // We don't need to check if the list is initialized
        // If a list is not initialized then there is no "previous" that is in the list
        // Therefore, this will revert.

        // Check that the value is not already in the list
        // We cannot add the max value to the list
        if (contains(list, value) || value == MAX || value == ZERO) revert ValueInList();

        // Get the next value
        bytes32 next = list.next[previous];

        // Check that the previous value is in the list
        if (next == ZERO) revert InvalidPreviousValue();

        // The list is sorted smallest to largest.
        // Therefore, we need previous < value < next
        // We know it cannot be equal because the above checks would not pass
        // i.e. a value cannot be both in and not in the list
        if (previous > value || value > next) revert InvalidValue();

        // Insert the value
        list.next[previous] = value;
        list.next[value] = next;

        // Increment the number of values in the list
        unchecked {
            list.count++;
        }
    }

    function remove(LinkedList storage list, bytes32 previous, bytes32 value) internal {
        // Check that the value is in the list and is not the ZERO value
        bytes32 next = list.next[value];
        if (value == ZERO || next == ZERO) revert ValueNotInList();

        // Check that the previous value points to the value
        if (list.next[previous] != value) revert InvalidPreviousValue();

        // Delete the value by removing it from the link chain
        // and removing its pointer to a non-zero value
        list.next[previous] = next;
        delete list.next[value];

        // Decrement the count
        list.count--;
    }
}
