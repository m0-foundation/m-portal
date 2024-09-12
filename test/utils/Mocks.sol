// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

contract MockBridge {
    function dispatch(
        uint256 chainId_,
        bytes calldata message_,
        uint32 gasLimit_,
        address refundAddress_
    ) external payable returns (bytes32 messageId_) {}

    function quote(
        uint256 chainId_,
        bytes calldata message_,
        uint32 gasLimit_
    ) external view returns (uint256 nativeFee_) {}
}

abstract contract MockMToken {
    uint128 public currentIndex;

    mapping(address account => uint256 balance) public balanceOf;

    mapping(address account => bool earning) public isEarning;

    function setCurrentIndex(uint128 currentIndex_) external {
        currentIndex = currentIndex_;
    }

    function setBalanceOf(address account_, uint256 balance_) external {
        balanceOf[account_] = balance_;
    }

    function setIsEarning(address account_, bool isEarning_) external {
        isEarning[account_] = isEarning_;
    }

    function approve(address spender_, uint256 amount_) external returns (bool) {}

    function transfer(address recipient_, uint256 amount_) external returns (bool success_) {}

    function transferFrom(address sender_, address recipient_, uint256 amount_) external returns (bool success_) {}

    function decimals() external pure returns (uint8) {}
}

contract MockHubMToken is MockMToken {}

contract MockSpokeMToken is MockMToken {
    function allowance(address account, address spender) external view returns (uint256) {}

    function mint(address account_, uint256 amount_, uint128 index_) external {}

    function burn(address account_, uint256 amount_) external {}

    function updateIndex(uint128 index) external {}
}

abstract contract MockPortal {
    function sendMToken(
        uint256 chainId,
        address recipient,
        uint256 amount,
        address refundAddress
    ) external payable returns (bytes32) {}

    function quoteSendMToken(uint256 chainId, address recipient, uint256 amount) external view returns (uint256) {}

    function receiveMToken(
        uint256 fromChainId,
        address sender,
        address recipient,
        uint256 amount,
        uint128 index
    ) external {}
}

contract MockHubPortal is MockPortal {}

contract MockSpokePortal is MockPortal {}

contract MockHubRegistrar {
    mapping(bytes32 key => bytes32 value) internal _values;

    mapping(bytes32 listName => mapping(address account => bool contains)) public listContains;

    function get(bytes32 key_) external view returns (bytes32 value_) {
        return _values[key_];
    }

    function set(bytes32 key_, bytes32 value_) external {
        _values[key_] = value_;
    }

    function setListContains(bytes32 listName_, address account_, bool contains_) external {
        listContains[listName_][account_] = contains_;
    }
}

contract MockSpokeRegistrar {
    function setKey(bytes32 key_, bytes32 value_) external {}

    function addToList(bytes32 list_, address account_) external {}

    function removeFromList(bytes32 list_, address account_) external {}
}

contract MockOptimismCrossDomainMessenger {
    function sendMessage(address target, bytes calldata message, uint32 minGasLimit) external {}

    function xDomainMessageSender() external view returns (address) {}
}

contract MockOptimismBridge {
    function receiveMessage(bytes calldata message, bytes32 messageId) external {}
}
