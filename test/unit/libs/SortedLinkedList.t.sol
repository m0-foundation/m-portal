// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "../../../lib/forge-std/src/Test.sol";

import { LinkedList, SortedLinkedList } from "../../../src/libs/SortedLinkedList.sol";

contract MockListUser {
    using SortedLinkedList for LinkedList;

    LinkedList internal _list;

    function initialize() external {
        _list.initialize();
    }

    function contains(bytes32 value) external view returns (bool) {
        return _list.contains(value);
    }

    function add(bytes32 previous, bytes32 value) external {
        _list.add(previous, value);
    }

    function remove(bytes32 previous, bytes32 value) external {
        _list.remove(previous, value);
    }

    function next(bytes32 value) external view returns (bytes32) {
        return _list.next[value];
    }

    function count() external view returns (uint256) {
        return _list.count;
    }
}

contract SortedLinkedListTest is Test {
    // test cases
    // [X] initialize
    //   [X] given the list hasn't been initialized before
    //     [X] it sets the start value's next value to the max value
    //   [X] given the list has been initialized before
    //     [X] given the list's member count is greater than zero
    //       [X] it reverts with an AlreadyInitialized error
    //     [X] given the list's member count is zero
    //       [X] nothing happens
    // [X] contains
    //   [X] given the list is empty
    //     [X] given the value is not in the list
    //       [X] it returns false
    //     [X] given the value is the start value
    //       [X] it returns true
    //   [X] given the list is non-empty
    //     [X] given the value is not in the list
    //       [X] it returns false
    //     [X] given the value is in the list
    //       [X] it returns true
    // [X] add
    //   [X] given the list is empty
    //     [X] given the value is already in the list (start value)
    //       [X] it reverts with a ValueInList error
    //     [X] given the value is not in the list
    //       [X] it updates the start value's next value to the value
    //       [X] it updates the value's next value to the max value
    //       [X] it increments the count
    //   [X] given the list is non-empty
    //     [X] given the value is already in the list
    //       [X] it reverts with a ValueInList error
    //     [X] given the value is not already in the list
    //       [X] given the previous value is not in the list
    //         [X] it reverts with a InvalidPreviousValue error
    //       [X] given the previous value is in the list
    //         [X] given the previous value is greater than the value
    //           [X] it reverts with an InvalidValue error
    //         [X] given the previous value is less than the value
    //           [X] given the value is greater than the current next value
    //             [X] it reverts with an InvalidValue error
    //           [X] given the value is less than the current next value
    //             [X] it updates the value after "previous" to "value"
    //             [X] it updates the value after "value" to previous' current next value
    //             [X] it increments the count
    // [X] remove
    //   [ ] given the value is zero
    //     [ ] it reverts with a ValueNotInList error
    //   [X] given the value is not in the list
    //     [X] it reverts with a ValueNotInList error
    //   [X] given the value is in the list
    //     [X] given the value is not after the previous value in the list
    //       [X] it reverts with a InvalidpreviousValue error
    //     [X] given the value is after the previous value in the list
    //       [X] it updates the value after "previous" to the value's current next value
    //       [X] it deletes the pointer from value to the next value
    //       [X] it decrements the count

    // State

    bytes32 public constant ZERO = bytes32(0);
    bytes32 public constant MAX = bytes32(type(uint256).max);
    MockListUser public list;

    // Convenience functions
    function _getPreviousValue(bytes32 value) internal view returns (bytes32) {
        bytes32 current = ZERO;
        bytes32 next = list.next(current);
        while (next < value) {
            current = next;
            next = list.next(current);
        }
        return current;
    }

    function _addRandomValues(uint8 number, bytes32 startValue) internal {
        bytes32 next = startValue;
        for (uint8 i = 0; i < number; i++) {
            bytes32 previous = _getPreviousValue(next);
            list.add(previous, next);
            next = keccak256(abi.encodePacked(next));
        }
    }

    // Tests

    function setUp() public {
        list = new MockListUser();
    }

    /* ========== initialize ========== */

    // given the list hasn't been initialized before
    // it sets the start value's next value to the max value
    function test_initialize_notInitializedBefore_success() external {
        assertEq(list.next(ZERO), ZERO);
        assertEq(list.count(), 0);

        list.initialize();

        assertEq(list.next(ZERO), MAX);
        assertEq(list.count(), 0);
    }

    // given the list has been initialized before
    // given the list's member count is greater than zero
    // it reverts with an AlreadyInitialized error
    function test_initialize_initializedBefore_nonEmpty_reverts() external {
        list.initialize();
        list.add(ZERO, bytes32(uint256(1)));

        assertEq(list.count(), 1);

        // Try to initialize the list again
        // expect revert with AlreadyInitialized error
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.AlreadyInitialized.selector));
        list.initialize();
    }

    // given the list has been initialized before
    // given the list's member count is zero
    // nothing happens
    function test_initialize_initializedBefore_empty_success() external {
        // initialize the list once
        list.initialize();
        assertEq(list.count(), 0);
        assertEq(list.next(ZERO), MAX);

        // initialize the list again
        list.initialize();
        assertEq(list.count(), 0);
        assertEq(list.next(ZERO), MAX);
    }

    /* ========== contains ========== */

    // given the list is empty
    // given the value is not in the list
    // it returns false
    function testFuzz_contains_emptyList_notInList(bytes32 value) external {
        vm.assume(value != ZERO);
        list.initialize();

        assert(!list.contains(value));
    }

    // given the list is empty
    // given the value is the start value
    // it returns true
    function test_contains_emptyList_startValue() external {
        list.initialize();

        assert(list.contains(ZERO));
    }

    // given the list is non-empty
    // given the value is not in the list
    // it returns false
    function testFuzz_contains_nonEmptyList_notInList(uint8 valuesToAdd, bytes32 testValue) external {
        valuesToAdd = (valuesToAdd % 20) + 1;
        vm.assume(testValue != ZERO);

        list.initialize();

        // Add random values to the list
        // The test value will not be one of them (or we have found a hash collision)
        _addRandomValues(valuesToAdd, keccak256(abi.encodePacked(testValue)));

        assert(!list.contains(testValue));
    }

    // given the list is non-empty
    // given the value is in the list
    // it returns true
    function testFuzz_contains_nonEmptyList_inList(uint8 valuesToAdd, bytes32 testValue) external {
        valuesToAdd = (valuesToAdd % 20) + 1;
        vm.assume(testValue != ZERO);

        list.initialize();

        // Add random values to the list
        // The test value will be one of them
        _addRandomValues(valuesToAdd, testValue);

        assert(list.contains(testValue));
    }

    /* ========== add ========== */

    // given the list is empty
    // given the value is already in the list (start value)
    // it reverts with a ValueInList error
    function test_add_emptyList_alreadyInList_reverts() external {
        list.initialize();

        // Try to add the start value again
        // expect revert with ValueInList error
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.ValueInList.selector));
        list.add(ZERO, ZERO);
    }

    // given the list is empty
    // given the value is not in the list
    // it updates the start value's next value to the value
    // it updates the value's next value to the max value
    // it increments the count
    function test_add_emptyList_notInList_success(bytes32 testValue) external {
        vm.assume(testValue != ZERO);
        list.initialize();

        // Verify the current state
        assertEq(list.count(), 0);
        assertEq(list.next(ZERO), MAX);

        // Add the test value
        list.add(ZERO, testValue);

        assertEq(list.next(ZERO), testValue);
        assertEq(list.next(testValue), MAX);
        assertEq(list.count(), 1);
    }

    // given the list is non-empty
    // given the value is already in the list
    // it reverts with a ValueInList error
    function testFuzz_add_nonEmptyList_alreadyInList_reverts(uint8 valuesToAdd, bytes32 testValue) external {
        valuesToAdd = (valuesToAdd % 20) + 1;
        vm.assume(testValue != ZERO);

        list.initialize();
        _addRandomValues(valuesToAdd, testValue);

        // Try to add the test value
        // expect revert with ValueInList error
        bytes32 previous = _getPreviousValue(testValue);
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.ValueInList.selector));
        list.add(previous, testValue);
    }

    // given the list is non-empty
    // given the value is not already in the list
    // given the previous value is not in the list
    // it reverts with a InvalidPreviousValue error
    function testFuzz_add_nonEmptyList_notInList_prevNotInList_reverts(
        uint8 valuesToAdd,
        bytes32 testValue,
        bytes32 previousValue
    ) external {
        valuesToAdd = (valuesToAdd % 20) + 1;
        vm.assume(testValue != ZERO);
        list.initialize();

        // Add random values, but not the test value
        _addRandomValues(valuesToAdd, keccak256(abi.encodePacked(testValue)));

        // Check that the previous value is not in the list
        vm.assume(!list.contains(previousValue));

        // Try to add a value with a previous value that is not in the list
        // expect revert with InvalidPreviousValue error
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.InvalidPreviousValue.selector));
        list.add(previousValue, testValue);
    }

    // given the list is non-empty
    // given the value is not already in the list
    // given the previous value is in the list
    // given the previous value is greater than the value
    // it reverts with an InvalidValue error
    function testFuzz_add_nonEmptyList_notInList_prevInList_prevGreater_reverts(
        uint8 valuesToAdd,
        bytes32 testValue,
        bytes32 previousValue
    ) external {
        valuesToAdd = (valuesToAdd % 20) + 1;
        vm.assume(testValue != ZERO);
        vm.assume(previousValue > testValue);
        list.initialize();

        // Add the previous value to the list
        list.add(ZERO, previousValue);

        // Add random values, but not the test value
        _addRandomValues(valuesToAdd, keccak256(abi.encodePacked(testValue)));

        // Try to add a value with a previous value that is greater than the value
        // expect revert with InvalidValue error
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.InvalidValue.selector));
        list.add(previousValue, testValue);
    }

    // given the list is non-empty
    // given the value is not already in the list
    // given the previous value is in the list
    // given the previous value is less than the value
    // given the value is greater than the current next value
    // it reverts with an InvalidValue error
    function testFuzz_add_nonEmptyList_notInList_prevInList_prevLess_valueGreater_reverts(
        uint8 valuesToAdd,
        bytes32 testValue,
        bytes32 previousValue
    ) external {
        valuesToAdd = (valuesToAdd % 20) + 1;
        vm.assume(previousValue != ZERO);
        vm.assume(testValue > previousValue);
        list.initialize();

        // Add the previous value to the list
        list.add(ZERO, previousValue);

        // Add random values, but not the test value
        _addRandomValues(valuesToAdd, keccak256(abi.encodePacked(testValue)));

        vm.assume(list.next(previousValue) < testValue);

        // Try to add a value with a value that is greater than the current next value
        // expect revert with InvalidValue error
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.InvalidValue.selector));
        list.add(previousValue, testValue);
    }

    // given the list is non-empty
    // given the value is not already in the list
    // given the previous value is in the list
    // given the previous value is less than the value
    // given the value is less than the current next value
    // it updates the value after "previous" to "value"
    // it updates the value after "value" to previous' current next value
    // it increments the count
    function testFuzz_add_nonEmptyList_notInList_prevInList_prevLess_valueLess_success(
        uint8 valuesToAdd,
        bytes32 randomSeed,
        bytes32 previousValue
    ) external {
        valuesToAdd = (valuesToAdd % 20) + 1;
        vm.assume(previousValue != ZERO && previousValue < bytes32(type(uint256).max - 1));
        list.initialize();

        // Add the previous value to the list
        list.add(ZERO, previousValue);

        // Add random values, but not the test value
        _addRandomValues(valuesToAdd, keccak256(abi.encodePacked(randomSeed)));

        // Set the value to be added as the previous value plus 1
        bytes32 newValue = bytes32(uint256(previousValue) + 1);

        vm.assume(!list.contains(newValue));

        // Verify the current state
        assertEq(list.count(), valuesToAdd + 1);
        bytes32 currentNext = list.next(previousValue);
        assertNotEq(currentNext, newValue);

        // Add the new value
        list.add(previousValue, newValue);

        assertEq(list.next(previousValue), newValue);
        assertEq(list.next(newValue), currentNext);
        assertEq(list.count(), valuesToAdd + 2);
    }

    /* ========== remove ========== */

    // given the value is zero
    // it reverts with a ValueNotInList error
    function testFuzz_remove_zero_reverts(uint8 valuesToAdd, bytes32 testValue) external {
        vm.assume(valuesToAdd <= 20);
        vm.assume(testValue != ZERO);
        list.initialize();

        // Add random values
        _addRandomValues(valuesToAdd, testValue);

        // Try to remove the zero value
        // expect revert with ValueNotInList error
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.ValueNotInList.selector));
        list.remove(testValue, ZERO);
    }

    // given the value is not in the list
    // it reverts with a ValueNotInList error
    function testFuzz_remove_notInList_reverts(uint8 valuesToAdd, bytes32 testValue) external {
        valuesToAdd = (valuesToAdd % 20) + 1;
        vm.assume(testValue != ZERO);
        list.initialize();

        // Add random values, but not the test value
        _addRandomValues(valuesToAdd, keccak256(abi.encodePacked(testValue)));

        // Try to remove a value that is not in the list
        // expect revert with ValueNotInList error
        bytes32 previous = _getPreviousValue(testValue);
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.ValueNotInList.selector));
        list.remove(previous, testValue);
    }

    // given the value is in the list
    // given the value is not after the previous value in the list
    // it reverts with a InvalidPreviousValue error
    function testFuzz_remove_inList_notAfterPrev_reverts(
        uint8 valuesToAdd,
        bytes32 testValue,
        bytes32 previousValue
    ) external {
        valuesToAdd = (valuesToAdd % 20) + 1;
        vm.assume(testValue != ZERO);
        list.initialize();

        // Add random values, including the test value
        _addRandomValues(valuesToAdd, testValue);

        // Get the previous value of the test value
        bytes32 previous = _getPreviousValue(testValue);
        vm.assume(previous != previousValue);

        // Try to remove a value that is not after the previous value
        // expect revert with InvalidPreviousValue error
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.InvalidPreviousValue.selector));
        list.remove(previousValue, testValue);
    }

    // given the value is in the list
    // given the value is after the previous value in the list
    // it updates the value after "previous" to the value's current next value
    // it deletes the pointer from value to the next value
    // it decrements the count
    function testFuzz_remove_inList_afterPrev_success(uint8 valuesToAdd, bytes32 testValue) external {
        valuesToAdd = (valuesToAdd % 20) + 1;
        vm.assume(testValue != ZERO);
        list.initialize();

        // Add random values, including the test value
        _addRandomValues(valuesToAdd, testValue);

        // Get the previous value of the test value
        bytes32 previous = _getPreviousValue(testValue);

        // Verify the current state
        assertEq(list.count(), valuesToAdd);
        assertEq(list.next(previous), testValue);
        bytes32 currentNext = list.next(testValue);
        assert(list.contains(testValue));

        // Remove the test value
        list.remove(previous, testValue);

        assertEq(list.next(previous), currentNext);
        assertEq(list.next(testValue), ZERO);
        assertEq(list.count(), valuesToAdd - 1);
        assert(!list.contains(testValue));
    }
}
