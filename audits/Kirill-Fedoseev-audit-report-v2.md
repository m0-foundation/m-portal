# M^0 M Portal Security Review

Date: **06.12.24**

Produced by **Kirill Fedoseev** (telegram: [kfedoseev](http://t.me/kfedoseev),
twitter: [@k1rill_fedoseev](http://twitter.com/k1rill_fedoseev))

## Introduction

An independent security review of the M^0 M Portal contracts was conducted by **kfedoseev** from 07.11.24 to 12.11.24.
The fixes review was conducted on 22.11.24 and on 06.12.24. The following methods were used for conducting a security
review:

- Manual source code review

## Disclaimer

No security review can guarantee or verify the absence of vulnerabilities. This security review is a time-bound process
where I tried to identify as many potential issues and vulnerabilities as possible, using my personal expertise in the
smart contract development and review.

## About M^0 M Portal

M Portal is a set of contracts built on top of the Wormhole NTT (Native Token Transfers) framework, designed to
facilitate bridging of M token between Ethereum Mainnet and various other chains.

## Observations and Limitations

- `HubPortal`, `SpokePortal` and `SpokeVault` contracts are upgradeable via the TTG governance. Registrar key-value
  pairs controlling the upgrade process can be directly altered through **StandardGovernor** or **EmergencyGovernor**,
  or indirectly through the **ZeroGovernor**. For `SpokeVault` and `SpokePortal`, registrar key values need to be
  additionally pushed through the Wormhole bridge using the `HubPortal`. Additionally, contracts can be upgraded by a
  migration admin (multi-sig), bypassing the governance upgradability flow. Upgradability is controlled by the
  implementation contract and can be forfeited in the future as part of one of the upgrades.

- While Wormhole bridge supports non-EVM chains, the current M Portal version targets only EVM-based chains. Forward
  compatibility with any non-EVM chains has not been assessed as part of the review.

## Severity classification

| **Severity**           | **Impact: High** | **Impact: Medium** | **Impact: Low** |
| ---------------------- | ---------------- | ------------------ | --------------- |
| **Likelihood: High**   | Critical         | High               | Medium          |
| **Likelihood: Medium** | High             | Medium             | Low             |
| **Likelihood: Low**    | Medium           | Low                | Low             |

**Impact** - the economic, technical, reputational or other damage to the protocol implied from a successful exploit.

**Likelihood** - the probability that a particular finding or vulnerability gets exploited.

**Severity** - the overall criticality of the particular finding.

## Scope summary

Reviewed commits:

- M Portal -
  [fd059a9f2a02d4c7522df19b1cf32f3d5ee45290](https://github.com/m0-foundation/m-portal/commit/fd059a9f2a02d4c7522df19b1cf32f3d5ee45290)
- Common -
  [3692db150ad90b21d7c213ea535f34792ad8873f](https://github.com/m0-foundation/common/commit/3692db150ad90b21d7c213ea535f34792ad8873f)
- Protocol (`spoke` branch) -
  [9661cce9b3562a7c17afc8b60dddf216c59de1f3](https://github.com/m0-foundation/protocol/commit/9661cce9b3562a7c17afc8b60dddf216c59de1f3)
- TTG (`spoke` branch) -
  [2a11c24f88f4b0b31e376dc61b73ab8a9a67190a](https://github.com/m0-foundation/ttg/commit/2a11c24f88f4b0b31e376dc61b73ab8a9a67190a)

Reviewed fixes commits:

- M Portal -
  [ddf583b9bef971752ec1360f9b089e6fefa9c526](https://github.com/m0-foundation/m-portal/tree/ddf583b9bef971752ec1360f9b089e6fefa9c526)
- Protocol (`spoke` branch) -
  [c8d6ac8244bf31a301e5744fa4ffa8ee8f1d5d7b](https://github.com/m0-foundation/protocol/tree/c8d6ac8244bf31a301e5744fa4ffa8ee8f1d5d7b)

Reviewed contracts:

- `m-portal/src/**`
- `common/src/**`
- `protocol/src/**`
- `ttg/src/**`

---

# Findings Summary

| ID     | Title                                                                                                      | Severity      | Status       |
| ------ | ---------------------------------------------------------------------------------------------------------- | ------------- | ------------ |
| [M-01] | Accrual of unbacked yield when enabling earning for `HubPortal`                                            | Medium        | Fixed        |
| [M-02] | Unchecked underflow in `outstandingPrincipal` calculation                                                  | Medium        | Fixed        |
| [L-01] | Missing `additionalPayload` length validation                                                              | Low           | Fixed        |
| [L-02] | Missing `TransferRedeemed` event emittance in `_receiveMToken`                                             | Low           | Fixed        |
| [L-03] | Race condition in messages sent via `sendRegistrarListStatus` and `sendRegistrarKey`                       | Low           | Acknowledged |
| [L-04] | Missing fee refund in `transferExcessM`                                                                    | Low           | Fixed        |
| [I-01] | Incorrect NatSpec comment for `currentIndex`                                                               | Informational | Fixed        |
| [I-02] | Unused function `toAddress`                                                                                | Informational | Fixed        |
| [I-03] | Use empty bytes for `DEFAULT_TRANSCEIVER_INSTRUCTIONS`                                                     | Informational | Acknowledged |
| [I-04] | Function `_receiveCustomPayload` in `SpokePortal` does not reject messages not coming from the `HubPortal` | Informational | Acknowledged |
| [I-05] | Typos in NatSpec comments                                                                                  | Informational | Fixed        |
| [I-06] | Whitelisting smart contracts based on chain-agnostic addresses is error-prone                              | Informational | Acknowledged |

# Security & Economic Findings

## [M-01] Accrual of unbacked yield when enabling earning for `HubPortal`

Assuming `HubPortal` will be deployed and used before TTG governance approves its inclusion into the earners list,
earners that are already in the list can generate unbacked yield on M Token on L2. Consider the following series of
events:

1. Portals are fully deployed and operational, however earning for `HubPortal` address hasn't been enabled yet (e.g. due
   to TTG governance delay).
2. A user who is already an earner on L1 bridges their M token to L2 through `HubPortal`
   1. Index 0 is sent along with the M-minting message (since `_currentIndex()` returns 0)
   2. `SpokePortal` ignores received index 0, since it's lower than `_currentIndex()` initialized as `EXP_SCALED_ONE`
      during M token deployment
3. User enables earning for their bridged M with contract assuming that the index is `EXP_SCALED_ONE`
4. TTG governance fully enables earning for `HubPortal`
5. Actual `index` is pushed to the L2 through the `HubPortal`
6. User M balance on L2 accrues yield assuming index changed from `EXP_SCALED_ONE` to the received `index`, while the
   actual index increase on L1 has been much lower

### Recommendation

Disallow `startEarning()` on Spoke M Token if `currentIndex() == EXP_SCALED_ONE`. Rework `outstandingPrincipal`
accordingly.

## [M-02] Unchecked underflow in `outstandingPrincipal` calculation

Applied changes to `outstandingPrincipal` are always rounded down when calculating principal amount from present amount.
It's possible to cause unchecked underflow. For example, assume that index is 1.1 and 3 wei of M token is bridged in
twice, then 6 wei is bridged back (`floor(3 / 1.1) + floor(3 / 1.1) < floor(6 / 1.1)`).

### Recommendation

Adopt one of the following:

- Round amounts that are bridged in upwards
- Remove `outstandingPrincipal` and count `excess` in Spoke M instead of `SpokePortal`, based on the
  `totalNonEarningSupply` and change in the index as part of `updateIndex`

## [L-01] Missing `additionalPayload` length validation

The `PayloadEncoder` function `decodeTokenTransfer` does not validate length of the `additionalPayload`. Such a check is
present for all `payload` decoding functions, however. Since `additionalPayload` is also used to store `index` and has a
fixed length, its length validation is also expected.

### Recommendation

Add the following validation:

```diff
 TransceiverStructs.NativeTokenTransfer memory nativeTokenTransfer_ = TransceiverStructs
     .parseNativeTokenTransfer(payload_);

 (index_, ) = nativeTokenTransfer_.additionalPayload.asUint64(0);
+nativeTokenTransfer_.additionalPayload.checkLength(8);
```

## [L-02] Missing `TransferRedeemed` event emittance in `_receiveMToken`

The `Portal` contract overrides the `NTTManager` inbound message handling logic. The original logic contained a
`TransferRedeemed` event, which is not present in the overridden implementation.

### Recommendation

Add the missing emit statement in `receiveMToken`.

## [L-03] Race condition in messages sent via `sendRegistrarListStatus` and `sendRegistrarKey`

Wormhole does not provide strong guarantees about the delivery order of cross-chain messages. Therefore, applications
should assume that messages can be delivered in arbitrary order. The execution result of messages sent from `HubPortal`
to `SpokePortal` using `sendRegistrarListStatus` and `sendRegistrarKey` depends on their delivery order.

For example, consider the following sequence of events:

1. `sendRegistrarKey` for key `X` (message 1)
2. `setKey` for key `X` that updates the value
3. `sendRegistrarKey` for key `X` (message 2)
4. Message 2 gets delivered and executed
5. Message 1 gets delivered and executed

As a result, values for key `X` will differ between Ethereum Mainnet and L2 until the key is sent again. The severity of
this issue is marked as Low, assuming all messages are relayed automatically via the Standard Wormhole Relayer. Note
that without an automated relayer, an attacker could pre-send many messages with old registrar values to stall key
update propagation for a prolonged time by reverting the key back to the original value immediately after someone tries
to update it using `sendRegistrarKey`.

With all messages relayed automatically, the impact is limited to a small set of DOS opportunities. For example, an
attacker could break `enableEarning` in Smart M L2 deployment via the following sequence of events (e.g. 2-4 and 5-8 can
happen in the same block):

1. TTG approves the L2 Smart M addition to the `EARNERS_LIST`
2. Attacker uses `sendRegistrarListStatus` to send `false` inclusion status for Smart M (message 1)
3. TTG proposal is executed, `addToList` is called
4. Attacker uses `sendRegistrarListStatus` to send `true` inclusion status for Smart M (message 2)
5. Message 2 gets delivered and executed (Smart M is added to the `EARNERS_LIST`)
6. Attacker calls `enableEarning()` on L2 Smart M
7. Message 1 gets delivered and executed (Smart M is removed from the `EARNERS_LIST`)
8. Attacker calls `disableEarning()` on L2 Smart M
9. It's no longer possible to re-enable earning via `enableEarning()` due to `EarningCannotBeReenabled()` revert

### Recommendation

Consider caching the last message sequence for each particular registrar key updated in `SpokePortal` and reverting all
messages that were sent before the last one applied to the particular key.

## [L-04] Missing fee refund in `transferExcessM`

The function `transferExcessM` calls `SpokePortal` to transfer M tokens back to Ethereum Mainnet. While doing so, it
forwards the `msg.value` to the `NTTManager`, which refunds the gas fee partially if the price quotes are updated (see
`_prepareForTransfer`). The gas fee is refunded to the `msg.sender`, which is the `SpokeVault` contract, however
`SpokeVault` does not forward it back to the caller.

### Recommendation

Add the following or similar refund forwarding logic to the `transferExcessM` function:

```diff
+uint256 oldBalance_ = address(this).balance;
 messageSequence_ = INttManager(spokePortal).transfer{ value: msg.value }(
     amount_,
     destinationChainId,
     hubVault_,
     refundAddress_,
     false,
     new bytes(1)
 );
+uint256 refund_ = address(this).balance - oldBalance_;
+if (refund_ > 0) {
+    (bool refundSuccessful,) = payable(msg.sender).call{value: refund_}("");
+
+    if (!refundSuccessful) {
+        revert RefundFailed(refund_);
+    }
+}
```

# Informational & Gas Optimizations

## [I-01] Incorrect NatSpec comment for `currentIndex`

The NatSpec comment for `currentIndex` in `IContinuousIndexing` references `updateIndex`, which works differently in the
spoke M version. Consider updating the NatSpec comment to reflect the current implementation.

```solidity
/// @notice The current index that would be written to storage if `updateIndex` is called.
function currentIndex() external view returns (uint128);
```

## [I-02] Unused function `toAddress`

The `toAddress` function in the spoke version of `Registrar` is unused and can be safely removed. Consider removing it.

## [I-03] Use empty bytes for `DEFAULT_TRANSCEIVER_INSTRUCTIONS`

The `WormholeTransceiver` accepts empty transceiver instructions and defaults to `shouldSkipRelayerSend = false`, as
shown in `parseWormholeTransceiverInstruction`. To save gas and reduce calldata size, consider using empty bytes value
for `DEFAULT_TRANSCEIVER_INSTRUCTIONS` in both `HubPortal` and `SpokeVault`.

## [I-04] Function `_receiveCustomPayload` in `SpokePortal` does not reject messages not coming from the `HubPortal`

The `_receiveCustomPayload` function in `SpokePortal` is intended to only handle messages from `HubPortal`. However, it
does not validate the source chain ID of delivered messages. The underlying `NttManager` treats all messages from
whitelisted peers the same way. As an extra safeguard, consider validating source chain ID according to the "Principal
Of Least Authority".

## [I-05] Typos in NatSpec comments

In the `ISpokeVault.sol`:

```diff
-* @param  refundAddress   The address to which a refund for unussed gas is issued on the destination chain.
+* @param  refundAddress   The address to which a refund for unused gas is issued on the destination chain.
```

In the `SpokePortal.sol`

```diff
-/// @dev Decreases `outstandingPrincipal` after M tokens are transfered out,
+/// @dev Decreases `outstandingPrincipal` after M tokens are transferred out,
```

## [I-06] Whitelisting smart contracts based on chain-agnostic addresses is error-prone

The current implementation of the `EARNERS` Registrar whitelist is chain-agnostic, meaning that the same address is
treated identically across different L2s. This implicitly assumes that the same address on different chains is
controlled by the same party. However, for smart contracts, this assumption may not hold true. For example, if the
deployer key for `HubPortal` is compromised, it could be used to deploy malicious contracts on L2s with the same address
to gain unauthorized access to earning functionality. Since `HubPortal` is a system contract designed to always be
earning, there would be no straightforward way to block the malicious party's earning access.

Consider either:

1. Maintaining separate earner whitelists for different chains, or
2. Modifying the deployment process to use deterministic `CREATE2` deployments for contracts like `HubPortal` and
   `SmartMToken` (e.g., Foundry scripts use https://github.com/Arachnid/deterministic-deployment-proxy by default for
   `CREATE2` calls).
