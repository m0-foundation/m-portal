// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Registrar } from "../../lib/ttg/src/Registrar.sol";
import { MerkleTreeBuilder } from "../../src/MerkleTreeBuilder.sol";
import { SortedLinkedList } from "../../src/libs/SortedLinkedList.sol";

contract MerkleTreeBuilderTest is Test {
    MerkleTreeBuilder public merkleTreeBuilder;
    Registrar public registrar;

    uint8 public constant ZERO_BIT = 0;
    uint8 public constant ONE_BIT = 1;
    bytes32 public constant LIST = bytes32("m-earners");
    bytes32 public constant ZERO = bytes32(0);
    bytes32 public constant ONE = bytes32(uint256(1));
    bytes32 public constant MAX = bytes32(type(uint256).max);

    function setUp() public {
        // We're using the spoke version of the registrar for simplicity
        // The functionality we use is the same between hub and spoke versions
        // We set the test contract as the "portal", which is permissioned to set values
        registrar = new Registrar(address(this));
        merkleTreeBuilder = new MerkleTreeBuilder(address(registrar));
    }

    function _getValueBefore(bytes32 list, bytes32 value) internal view returns (bytes32) {
        bytes32 before = ZERO;
        if (merkleTreeBuilder.getLen(list) == 0) {
            return before;
        }

        bytes32 current = merkleTreeBuilder.getNext(list, before);
        while (current < value) {
            before = current;
            current = merkleTreeBuilder.getNext(list, before);
        }

        return before;
    }

    function _addRandomValues(uint16 number, bytes32 list, bytes32 start) internal {
        bytes32 current = start;
        for (uint8 i = 0; i < number; i++) {
            registrar.setKey(keccak256(abi.encodePacked(list, current)), ONE);
            bytes32 before = _getValueBefore(list, current);
            merkleTreeBuilder.addToList(list, before, current);
            current = keccak256(abi.encodePacked(current));
        }
    }

    // test cases
    // [X] addToList
    //   [X] given value is not set on the registrar for the calculated key
    //     [X] given the list is empty
    //       [X] it reverts with error 'InvalidAdd'
    //     [X] given the list is not empty
    //       [X] it reverts with error 'InvalidAdd'
    //   [X] given value is set on the registrar for the calculated key
    //     [X] given the list is empty
    //       [X] given the value is the zero value
    //         [X] it reverts with error 'ValueInList'
    //       [X] given the value is not the zero value
    //         [X] it initializes the list
    //     [X] given the list is not empty
    //       [X] given the value is the zero value
    //         [X] it reverts with a 'ValueInList' error
    //       [X] given the value is in the list
    //         [X] it reverts with error 'ValueInList'
    //       [X] given the value is not in the list
    //         [X] given the before value is not in the list
    //           [X] it reverts with error 'InvalidPreviousValue'
    //         [X] given the before value is not immediately before where the value should be inserted
    //           [X] it reverts with error 'InvalidValue'
    //         [X] given the before value is immediately before where the value should be inserted
    //           [X] it adds the value to the list
    //           [X] it increments the number of values in the list
    // [X] removeFromList
    //   [X] given value is set on the registrar for the calculated key
    //     [X] it reverts with error 'InvalidRemove'
    //   [X] given value is not set on the registrar for the calculated key
    //     [X] given the value is not in the list
    //       [X] it reverts with error 'ValueNotInList'
    //     [X] given the value is in the list
    //       [X] given the before value is not immediately before the value
    //         [X] it reverts with error 'InvalidPreviousValue'
    //       [X] given the before value is immediately before the value
    //         [X] it removes the value from the list
    //         [X] it decrements the number of values in the list
    // [X] updateRoot
    //   [X] given the list is empty
    //     [X] it sets the root to the hash of the zero bytes32 value
    //   [X] given the list has one member
    //     [X] it sets the root to the hash of the member
    //   [ ] given the list has a power-of-two number of members
    //     [ ] it sets the root correctly
    //   [ ] given the list has an even, none-power-of-two number of members
    //     [ ] it sets the root correctly
    //   [ ] given the list has an odd number of members
    //     [ ] it sets the root correctly

    /* ========== addToList ========== */

    // given the value is not set on the registrar for the calculated key
    // given the list is empty
    // it reverts with error 'InvalidAdd'
    function testFuzz_addToList_valueNotSet_listEmpty_reverts(bytes32 value) public {
        // There are no values set on the registrar so they should all revert

        // The list is empty so the before value is the zero bytes32 value
        vm.expectRevert(abi.encodeWithSelector(MerkleTreeBuilder.InvalidAdd.selector));
        merkleTreeBuilder.addToList(LIST, ZERO, value);
    }

    // given the value is not set on the registrar for the calculated key
    // given the list is not empty
    // it reverts with error 'InvalidAdd'
    function testFuzz_addToList_valueNotSet_listNotEmpty_reverts(uint8 valuesToAdd, bytes32 value) public {
        vm.assume(valuesToAdd > 0 && valuesToAdd <= 20);
        vm.assume(value != ZERO);

        // Set some values on the registrar but not the value we want to add
        _addRandomValues(valuesToAdd, LIST, keccak256(abi.encodePacked(value)));

        vm.assume(!merkleTreeBuilder.contains(LIST, value));

        // The list is not empty so the before value is the value before the one we want to add
        bytes32 before = _getValueBefore(LIST, value);

        // The value is not set on the registrar so it should revert
        vm.expectRevert(abi.encodeWithSelector(MerkleTreeBuilder.InvalidAdd.selector));
        merkleTreeBuilder.addToList(LIST, before, value);
    }

    // given the value is set on the registrar for the calculated key
    // given the list is empty
    // given the value is the zero value
    // it reverts with error 'ValueInList'
    function test_addToList_valueSet_listEmpty_valueIsZero_reverts() public {
        // Add the zero value to the registrar
        // This shouldn't be done, but just to cover all of the cases
        registrar.setKey(keccak256(abi.encodePacked(LIST, ZERO)), ONE);

        // The value is set on the registrar so it should revert
        vm.expectRevert(abi.encodeWithSelector(MerkleTreeBuilder.ValueInList.selector));
        merkleTreeBuilder.addToList(LIST, ZERO, ZERO);
    }

    // given the value is set on the registrar for the calculated key
    // given the list is empty
    // given the value is not the zero value
    // it initializes the list
    // it adds the value to the list
    // it increments the number of values in the list
    function testFuzz_addToList_valueSet_listEmpty_valueNotZero_success(bytes32 value) public {
        vm.assume(value != ZERO);

        // Set the value on the registrar
        registrar.setKey(keccak256(abi.encodePacked(LIST, value)), ONE);

        assertEq(merkleTreeBuilder.getLen(LIST), 0);

        // The list is empty so the before value is the zero bytes32 value
        merkleTreeBuilder.addToList(LIST, ZERO, value);

        // Check that the value is in the list
        assertTrue(merkleTreeBuilder.contains(LIST, value));

        // Check that the length of the list is now 1
        assertEq(merkleTreeBuilder.getLen(LIST), 1);

        // Check that the tree was initialized
        // The zero value should point to the added value as its next
        // The value should point to the max bytes32 value as its next
        assertEq(merkleTreeBuilder.getNext(LIST, ZERO), value);
        assertEq(merkleTreeBuilder.getNext(LIST, value), MAX);

        // The list itself should only contain the value
        bytes32[] memory list = merkleTreeBuilder.getList(LIST);
        assertEq(list.length, 1);
        assertEq(list[0], value);
    }

    // given the value is set on the registrar for the calculated key
    // given the list is not empty
    // given the value is the zero value
    // it reverts with a 'ValueInList' error
    function test_addToList_valueSet_listNotEmpty_valueZero_reverts(uint8 valuesToAdd) public {
        // Add the zero value to the registrar
        // This shouldn't be done, but just to cover all of the cases
        registrar.setKey(keccak256(abi.encodePacked(LIST, ZERO)), ONE);

        // Add random values to the list
        _addRandomValues(valuesToAdd, LIST, keccak256(abi.encodePacked(ZERO)));

        // The list is not empty so the before value is the value before the one we want to add
        bytes32 before = _getValueBefore(LIST, ZERO);

        // The value is set on the registrar so it should revert
        vm.expectRevert(abi.encodeWithSelector(MerkleTreeBuilder.ValueInList.selector));
        merkleTreeBuilder.addToList(LIST, before, ZERO);
    }

    // given the value is set on the registrar for the calculated key
    // given the list is not empty
    // given the value is not zero
    // given the value is in the list
    // it reverts with error 'ValueInList'
    function testFuzz_addToList_valueSet_listNotEmpty_valueNotZero_valueInList_reverts(
        uint8 valuesToAdd,
        bytes32 value
    ) public {
        vm.assume(valuesToAdd > 0 && valuesToAdd <= 20);
        vm.assume(value != ZERO);

        // Set some values on the registrar, including the value we want to add
        _addRandomValues(valuesToAdd, LIST, value);

        // The list is not empty so the before value is the value before the one we want to add
        bytes32 before = _getValueBefore(LIST, value);

        // The value is set on the registrar so it should revert
        vm.expectRevert(abi.encodeWithSelector(MerkleTreeBuilder.ValueInList.selector));
        merkleTreeBuilder.addToList(LIST, before, value);
    }

    // given the value is set on the registrar for the calculated key
    // given the list is not empty
    // given the value is not zero
    // given the value is not in the list
    // given the before value is not in the list
    // it reverts with error 'InvalidPreviousValue'
    function testFuzz_addToList_valueSet_listNotEmpty_valueNotZero_valueNotInList_beforeNotInList_reverts(
        uint8 valuesToAdd,
        bytes32 value
    ) public {
        vm.assume(valuesToAdd > 0 && valuesToAdd <= 20);
        vm.assume(value != ZERO);

        // Set some values on the registrar but not the value we want to add
        _addRandomValues(valuesToAdd, LIST, keccak256(abi.encodePacked(value)));

        vm.assume(!merkleTreeBuilder.contains(LIST, value));

        // Set the key in the registrar
        registrar.setKey(keccak256(abi.encodePacked(LIST, value)), ONE);

        // The list is not empty so the before value is the value before the one we want to add
        // We hash this so it's not the correct value
        bytes32 before = keccak256(abi.encodePacked(_getValueBefore(LIST, value)));
        vm.assume(!merkleTreeBuilder.contains(LIST, before));

        // The value is not in the list so it should revert
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.InvalidPreviousValue.selector));
        merkleTreeBuilder.addToList(LIST, before, value);
    }

    // given the value is set on the registrar for the calculated key
    // given the list is not empty
    // given the value is not zero
    // given the value is not in the list
    // given the before value is not immediately before where the value should be inserted
    // it reverts with error 'InvalidValue'
    function testFuzz_addToList_valueSet_listNotEmpty_valueNotZero_valueNotInList_wrongBefore_reverts(
        uint8 valuesToAdd,
        uint8 beforeIndex,
        bytes32 value
    ) public {
        vm.assume(valuesToAdd > 0 && valuesToAdd <= 20);
        vm.assume(value != ZERO);

        // Set some values on the registrar but not the value we want to add
        _addRandomValues(valuesToAdd, LIST, keccak256(abi.encodePacked(value)));

        vm.assume(!merkleTreeBuilder.contains(LIST, value));

        // Set the key in the registrar
        registrar.setKey(keccak256(abi.encodePacked(LIST, value)), ONE);

        // The list is not empty so the before value is the value before the one we want to add
        // We want a wrong before value so we make sure we don't use the correct one
        bytes32 actualBefore = _getValueBefore(LIST, value);

        bytes32[] memory list = merkleTreeBuilder.getList(LIST);
        bytes32 before = list[beforeIndex % valuesToAdd];

        vm.assume(before != actualBefore);

        // The value is not in the list so it should revert
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.InvalidValue.selector));
        merkleTreeBuilder.addToList(LIST, before, value);
    }

    // given the value is set on the registrar for the calculated key
    // given the list is not empty
    // given the value is not zero
    // given the value is not in the list
    // given the before value is immediately before where the value should be inserted
    // it adds the value to the list
    // it increments the number of values in the list
    function testFuzz_addToList_valueSet_listNotEmpty_valueNotZero_valueNotInList_correctBefore_success(
        uint8 valuesToAdd,
        bytes32 value
    ) public {
        vm.assume(valuesToAdd > 0 && valuesToAdd <= 20);
        vm.assume(value != ZERO);

        // Set some values on the registrar
        _addRandomValues(valuesToAdd, LIST, keccak256(abi.encodePacked(value)));

        // Set the value on the registrar
        registrar.setKey(keccak256(abi.encodePacked(LIST, value)), ONE);

        assertEq(merkleTreeBuilder.getLen(LIST), valuesToAdd);

        // The list is not empty so the before value is the value before the one we want to add
        bytes32 before = _getValueBefore(LIST, value);

        // The value is set on the registrar so it should revert
        merkleTreeBuilder.addToList(LIST, before, value);

        assertTrue(merkleTreeBuilder.contains(LIST, value));
        assertEq(merkleTreeBuilder.getLen(LIST), valuesToAdd + 1);
    }

    /* ========== removeFromList ========== */

    // given value is set on the registrar for the calculated key
    // it reverts with error 'InvalidRemove'
    function testFuzz_removeFromList_valueSet_reverts(bytes32 value) public {
        vm.assume(value != ZERO);

        // Set the value on the registrar
        registrar.setKey(keccak256(abi.encodePacked(LIST, value)), ONE);

        // The value is set on the registrar so it should revert
        vm.expectRevert(abi.encodeWithSelector(MerkleTreeBuilder.InvalidRemove.selector));
        merkleTreeBuilder.removeFromList(LIST, ZERO, value);
    }

    // given value is not set on the registrar for the calculated key
    // given the value is not in the list
    // it reverts with error 'ValueNotInList'
    function testFuzz_removeFromList_valueNotSet_valueNotInList_reverts(uint8 valuesToAdd, bytes32 value) public {
        vm.assume(valuesToAdd > 0 && valuesToAdd <= 20);
        vm.assume(value != ZERO);

        // Add random values to the list, excluding the one we want to remove
        _addRandomValues(valuesToAdd, LIST, keccak256(abi.encodePacked(value)));

        vm.assume(!merkleTreeBuilder.contains(LIST, value));

        // The value is not set on the registrar so it should revert
        vm.expectRevert(abi.encodeWithSelector(MerkleTreeBuilder.ValueNotInList.selector));
        merkleTreeBuilder.removeFromList(LIST, ZERO, value);
    }

    // given value is not set on the registrar for the calculated key
    // given the value is in the list
    // given the before value is not in the list
    // it reverts with error 'InvalidPreviousValue'
    function testFuzz_removeFromList_valueNotSet_valueInList_beforeNotInList_reverts(
        uint8 valuesToAdd,
        bytes32 value
    ) public {
        vm.assume(valuesToAdd > 0 && valuesToAdd <= 20);
        vm.assume(value != ZERO);

        // Add random values to the list including the one we want to remove
        _addRandomValues(valuesToAdd, LIST, value);

        // Create a random before value
        bytes32 before = keccak256(abi.encodePacked(value));
        vm.assume(!merkleTreeBuilder.contains(LIST, before));

        // Remove the value from the registrar
        registrar.setKey(keccak256(abi.encodePacked(LIST, value)), ZERO);

        // The value is not set on the registrar so it should revert
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.InvalidPreviousValue.selector));
        merkleTreeBuilder.removeFromList(LIST, before, value);
    }

    // given value is not set on the registrar for the calculated key
    // given the value is in the list
    // given the before value is not immediately before the value
    // it reverts with error 'InvalidPreviousValue'
    function testFuzz_removeFromList_valueNotSet_valueInList_wrongBefore_reverts(
        uint8 valuesToAdd,
        uint8 beforeIndex,
        bytes32 value
    ) public {
        vm.assume(valuesToAdd > 0 && valuesToAdd <= 20);
        vm.assume(value != ZERO);

        // Add random values to the list including the one we want to remove
        _addRandomValues(valuesToAdd, LIST, value);

        // Set the before value to a random one in the list that is not correct
        bytes32 actualBefore = _getValueBefore(LIST, value);
        bytes32[] memory list = merkleTreeBuilder.getList(LIST);
        bytes32 before = list[beforeIndex % valuesToAdd];
        vm.assume(before != actualBefore);

        // Remove the value from the registrar
        registrar.setKey(keccak256(abi.encodePacked(LIST, value)), ZERO);

        // The value is not set on the registrar so it should revert
        vm.expectRevert(abi.encodeWithSelector(SortedLinkedList.InvalidPreviousValue.selector));
        merkleTreeBuilder.removeFromList(LIST, before, value);
    }

    // given value is not set on the registrar for the calculated key
    // given the value is in the list
    // given the before value is immediately before the value
    // it removes the value from the list
    // it decrements the number of values in the list
    function testFuzz_removeFromList_valueNotSet_valueInList_correctBefore_success(
        uint8 valuesToAdd,
        bytes32 value
    ) public {
        vm.assume(valuesToAdd > 0 && valuesToAdd <= 20);
        vm.assume(value != ZERO);

        // Add random values to the list including the one we want to remove
        _addRandomValues(valuesToAdd, LIST, value);

        assertEq(merkleTreeBuilder.getLen(LIST), valuesToAdd);
        assertTrue(merkleTreeBuilder.contains(LIST, value));

        // Set the before value to the one before the value
        bytes32 before = _getValueBefore(LIST, value);

        // Remove the value from the registrar
        registrar.setKey(keccak256(abi.encodePacked(LIST, value)), ZERO);

        // The value is not set on the registrar so it should revert
        merkleTreeBuilder.removeFromList(LIST, before, value);

        assertFalse(merkleTreeBuilder.contains(LIST, value));
        assertEq(merkleTreeBuilder.getLen(LIST), valuesToAdd - 1);
    }

    /* ========== updateRoot ========== */

    // given the list is empty
    // it sets the root to the hash of the zero bytes32 value
    function test_updateRoot_listEmpty() public {
        // The list is empty so the root should be the hash of the zero bytes32 value
        merkleTreeBuilder.updateRoot(LIST);

        assertEq(merkleTreeBuilder.getRoot(LIST), keccak256(abi.encodePacked(ZERO_BIT, ZERO)));
    }

    // given the list has one member
    // it sets the root to the hash of the member
    function testFuzz_updateRoot_listOneMember(bytes32 value) public {
        vm.assume(value != ZERO);

        // Add a value to the list
        registrar.setKey(keccak256(abi.encodePacked(LIST, value)), ONE);
        merkleTreeBuilder.addToList(LIST, ZERO, value);

        // The list has one member so the root should be the hash of the member
        merkleTreeBuilder.updateRoot(LIST);

        bytes32 leaf = keccak256(abi.encodePacked(ZERO_BIT, value));

        assertEq(merkleTreeBuilder.getRoot(LIST), keccak256(abi.encodePacked(ONE_BIT, leaf, leaf)));
    }

    // given the list has two members
    // it sets the root correctly
    function testFuzz_updateRoot_listTwoMembers(bytes32 value1, bytes32 value2) public {
        vm.assume(value1 != ZERO && value2 != ZERO);
        vm.assume(value1 != value2);

        // Add two values to the list
        registrar.setKey(keccak256(abi.encodePacked(LIST, value1)), ONE);
        registrar.setKey(keccak256(abi.encodePacked(LIST, value2)), ONE);
        merkleTreeBuilder.addToList(LIST, ZERO, value1);
        bytes32 before = _getValueBefore(LIST, value2);
        merkleTreeBuilder.addToList(LIST, before, value2);

        // The list has two members so the root should be the hash of the two members
        merkleTreeBuilder.updateRoot(LIST);

        // Get the leaves
        bytes32 leaf1 = keccak256(abi.encodePacked(ZERO_BIT, value1));
        bytes32 leaf2 = keccak256(abi.encodePacked(ZERO_BIT, value2));

        // Calculate the root by hashing the leaves
        // The order depends on the order of the values in the list
        if (value1 < value2) {
            assertEq(merkleTreeBuilder.getRoot(LIST), keccak256(abi.encodePacked(ONE_BIT, leaf1, leaf2)));
        } else {
            assertEq(merkleTreeBuilder.getRoot(LIST), keccak256(abi.encodePacked(ONE_BIT, leaf2, leaf1)));
        }
    }

    // given the list has a power-of-two number of members
    // it sets the root correctly
    function test_updateRoot_listPowerOfTwoMembers(uint8 power, bytes32 seed) public {
        vm.assume(power > 0 && power <= 10);
        vm.assume(seed != ZERO);

        uint256 num = 2 ** power;
        // safe to cast down since power is <= 10
        _addRandomValues(uint16(num), LIST, seed);

        merkleTreeBuilder.updateRoot(LIST);

        // Check the size of the list
        assertEq(merkleTreeBuilder.getLen(LIST), num);

        // Calculate the root
        bytes32[] memory tree = new bytes32[](num);

        bytes32 previous = ZERO;
        for (uint256 i = 0; i < num; i++) {
            bytes32 value = merkleTreeBuilder.getNext(LIST, previous);
            tree[i] = keccak256(abi.encodePacked(ZERO_BIT, value));
            previous = value;
        }

        while (num > 1) {
            uint256 nextLen = num / 2;
            for (uint256 i = 0; i < num; i = i + 2) {
                bytes32 one = tree[i];
                bytes32 two = tree[i + 1];
                tree[i / 2] = keccak256(abi.encodePacked(ONE_BIT, one, two));
            }
            num = nextLen;
        }

        assertEq(merkleTreeBuilder.getRoot(LIST), tree[0]);
    }
}
