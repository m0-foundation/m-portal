// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { IMTokenLike, IRegistrarLike } from "./interfaces/Dependencies.sol";
import { IHubPortal } from "./interfaces/IHubPortal.sol";
import { ISpokePortal } from "./interfaces/ISpokePortal.sol";

import { Portal } from "./Portal.sol";

/**
 * @title  Portal residing on Ethereum Mainnet handling sending/receiving M and pushing the M index and Registrar keys.
 * @author M^0 Labs
 */
contract HubPortal is IHubPortal, Portal {
    /* ============ Variables ============ */

    /// @dev Registrar key holding value of whether the earners list can be ignored or not.
    bytes32 internal constant _EARNERS_LIST_IGNORED = "earners_list_ignored";

    /// @dev Registrar key of earners list.
    bytes32 internal constant _EARNERS_LIST = "earners";

    /// TODO: properly estimate the following gas limits
    /// @dev Gas limit for sending the index.
    uint32 internal constant _SEND_M_TOKEN_INDEX_GAS_LIMIT = 100_000;

    /// @dev Gas limit for sending a registrar key.
    uint32 internal constant _SEND_REGISTRAR_KEY_GAS_LIMIT = 150_000;

    /// @dev Gas limit for sending a registrar list status for an account.
    uint32 internal constant _SEND_REGISTRAR_LIST_STATUS_GAS_LIMIT = 150_000;

    /// @dev Array of indices at which earning was enabled or disabled.
    uint128[] internal _enableDisableEarningIndices;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the contract.
     * @param  bridge_    The address of the bridge that will dispatch and receive messages.
     * @param  mToken_    The address of the M token to bridge.
     * @param  registrar_ The address of the Registrar.
     */
    constructor(address bridge_, address mToken_, address registrar_) Portal(bridge_, mToken_, registrar_) {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IHubPortal
    function sendMTokenIndex(uint256 chainId_, address refundAddress_) external payable returns (bytes32 messageId_) {
        uint128 index_ = _currentIndex();

        messageId_ = _dispatch(
            chainId_,
            _encodeSendMTokenIndexMessage(index_),
            _SEND_M_TOKEN_INDEX_GAS_LIMIT,
            refundAddress_
        );

        emit MTokenIndexSent(chainId_, bridge, messageId_, index_);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarKey(
        uint256 chainId_,
        bytes32 key_,
        address refundAddress_
    ) external payable returns (bytes32 messageId_) {
        bytes32 value_ = IRegistrarLike(registrar).get(key_);

        messageId_ = _dispatch(
            chainId_,
            _encodeSetRegistrarKeyMessage(key_, value_),
            _SEND_REGISTRAR_KEY_GAS_LIMIT,
            refundAddress_
        );

        emit RegistrarKeySent(chainId_, bridge, messageId_, key_, value_);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarListStatus(
        uint256 chainId_,
        bytes32 listName_,
        address account_,
        address refundAddress_
    ) external payable returns (bytes32 messageId_) {
        bool status_ = IRegistrarLike(registrar).listContains(listName_, account_);

        messageId_ = _dispatch(
            chainId_,
            _encodeSetRegistrarListStatusMessage(listName_, account_, status_),
            _SEND_REGISTRAR_LIST_STATUS_GAS_LIMIT,
            refundAddress_
        );

        emit RegistrarListStatusSent(chainId_, bridge, messageId_, listName_, account_, status_);
    }

    /// @inheritdoc IHubPortal
    function enableEarning() external {
        if (!_isApprovedEarner()) revert NotApprovedEarner();
        if (isEarningEnabled()) revert EarningIsEnabled();

        // NOTE: This is a temporary measure to prevent re-enabling earning after it has been disabled.
        //       This line will be removed in the future.
        if (_enableDisableEarningIndices.length != 0) revert EarningCannotBeReenabled();

        uint128 currentMIndex_ = IMTokenLike(mToken).currentIndex();
        _enableDisableEarningIndices.push(currentMIndex_);

        IMTokenLike(mToken).startEarning();

        emit EarningEnabled(currentMIndex_);
    }

    /// @inheritdoc IHubPortal
    function disableEarning() external {
        if (_isApprovedEarner()) revert IsApprovedEarner();
        if (!isEarningEnabled()) revert EarningIsDisabled();

        uint128 currentMIndex_ = IMTokenLike(mToken).currentIndex();
        _enableDisableEarningIndices.push(currentMIndex_);

        IMTokenLike(mToken).stopEarning();

        emit EarningDisabled(currentMIndex_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IHubPortal
    function quoteSendMTokenIndex(uint256 chainId_) external view returns (uint256) {
        return _quote(chainId_, _encodeSendMTokenIndexMessage(_currentIndex()), _SEND_M_TOKEN_INDEX_GAS_LIMIT);
    }

    /// @inheritdoc IHubPortal
    function quoteSendRegistrarKey(uint256 chainId_, bytes32 key_) external view returns (uint256) {
        return
            _quote(
                chainId_,
                _encodeSetRegistrarKeyMessage(key_, IRegistrarLike(registrar).get(key_)),
                _SEND_REGISTRAR_KEY_GAS_LIMIT
            );
    }

    /// @inheritdoc IHubPortal
    function quoteSendRegistrarListStatus(
        uint256 chainId_,
        bytes32 listName_,
        address account_
    ) external view returns (uint256) {
        return
            _quote(
                chainId_,
                _encodeSetRegistrarListStatusMessage(
                    listName_,
                    account_,
                    IRegistrarLike(registrar).listContains(listName_, account_)
                ),
                _SEND_REGISTRAR_LIST_STATUS_GAS_LIMIT
            );
    }

    /// @inheritdoc IHubPortal
    function isEarningEnabled() public view returns (bool) {
        return IMTokenLike(mToken).isEarning(address(this));
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev   Locks M tokens from the caller before sending them to the destination chain.
     * @param amount_ The amount of M tokens to lock from the caller.
     */
    function _sendMToken(uint256 amount_) internal override {
        IERC20(mToken).transferFrom(msg.sender, address(this), amount_);
    }

    /**
     * @dev   Receive M tokens from the source chain.
     * @param recipient_ The account to unlock/transfer M tokens to.
     * @param amount_    The amount of M Token to unlock to the recipient.
     * @param index_     The index from the source chain.
     */
    function _receiveMToken(address recipient_, uint256 amount_, uint128 index_) internal override {
        IERC20(mToken).transfer(recipient_, amount_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Returns the current M token index used by the Hub Portal.
    function _currentIndex() internal view override returns (uint128) {
        if (isEarningEnabled()) {
            return IMTokenLike(mToken).currentIndex();
        }

        // If earning has been enabled in the past, return the latest recorded index when it was disabled.
        // Otherwise, return the starting index.
        return
            _enableDisableEarningIndices.length != 0
                ? _enableDisableEarningIndices[_enableDisableEarningIndices.length - 1]
                : 0;
    }

    /// @dev Returns whether the Hub Portal is a TTG-approved earner or not.
    function _isApprovedEarner() internal view returns (bool) {
        IRegistrarLike registrar_ = IRegistrarLike(registrar);

        return
            registrar_.get(_EARNERS_LIST_IGNORED) != bytes32(0) ||
            registrar_.listContains(_EARNERS_LIST, address(this));
    }

    /**
     * @dev    Encodes the message to update the M index on the destination chain.
     * @param  index_ The index to dispatch.
     * @return The encoded message.
     */
    function _encodeSendMTokenIndexMessage(uint128 index_) internal pure returns (bytes memory) {
        return abi.encodeCall(ISpokePortal.updateMTokenIndex, index_);
    }

    /**
     * @dev    Encodes the message to set a Registrar key on the destination chain.
     * @param  key_   The key to set.
     * @param  value_ The value to set.
     * @return The encoded message.
     */
    function _encodeSetRegistrarKeyMessage(bytes32 key_, bytes32 value_) internal pure returns (bytes memory) {
        return abi.encodeCall(ISpokePortal.setRegistrarKey, (key_, value_));
    }

    /**
     * @dev    Encodes the message to set the status of an account in a Registrar list on the destination chain.
     * @param  listName_ The name of the list.
     * @param  account_  The account.
     * @param  status_   The status of the account in the list.
     * @return The encoded message.
     */
    function _encodeSetRegistrarListStatusMessage(
        bytes32 listName_,
        address account_,
        bool status_
    ) internal pure returns (bytes memory) {
        return abi.encodeCall(ISpokePortal.setRegistrarListStatus, (listName_, account_, status_));
    }
}
