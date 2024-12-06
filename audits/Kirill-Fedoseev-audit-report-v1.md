# M^0 Usual Smart M Extension Security Review

Date: **22.11.24**

Produced by **Kirill Fedoseev** (telegram: [kfedoseev](http://t.me/kfedoseev),
twitter: [@k1rill_fedoseev](http://twitter.com/k1rill_fedoseev))

## Introduction

An independent security review of the M^0 Usual Smart M Extension contracts was conducted by **kfedoseev** on 22.11.24.
The following methods were used for conducting a security review:

- Manual source code review

## Disclaimer

No security review can guarantee or verify the absence of vulnerabilities. This security review is a time-bound process
where I tried to identify as many potential issues and vulnerabilities as possible, using my personal expertise in the
smart contract development and review.

## About M^0 Usual Smart M Extension

Usual Smart M Extension is a semi-permissioned ERC20 wrapper of Smart M token, designed to be used as collateral for
generating USD0.

## Observations and Limitations

* The `UsualM` contract is upgradeable, with upgradeability being managed by a multi-sig.
* `UsualM` wrapping is permissionless, however, unwrapping is permissioned and controlled by the Usual's
  `RegistryAccess` contract. `UsualM` also contains pausing and blacklisting functionality controlled by the roles
  defined in the Usual's `RegistryAccess` contract.
* Management and usage of the `UsualM` contract as well as all Smart M funds wrapped in `UsualM` are delegated to the
  Usual protocol and its smart contracts, whose security hasn't been evaluated as part of this review. From the Smart M
  perspective, `UsualM` is yet another user of the Smart M token with no additional permissions, thus, in the worst case
  scenario, regardless of `UsualM` contract behavior, other `Smart M` or `M` users won't be impacted in any way.

## Severity classification

| **Severity**           | **Impact: High** | **Impact: Medium** | **Impact: Low** |
|------------------------|------------------|--------------------|-----------------|
| **Likelihood: High**   | Critical         | High               | Medium          |
| **Likelihood: Medium** | High             | Medium             | Low             |
| **Likelihood: Low**    | Medium           | Low                | Low             |

**Impact** - the economic, technical, reputational or other damage to the protocol implied from a successful exploit.

**Likelihood** - the probability that a particular finding or vulnerability gets exploited.

**Severity** - the overall criticality of the particular finding.

## Scope summary

Reviewed commits:

* M Extensions -
  [7ed8340dcfdca31ae24c4d2ceca3bebb47798b04](https://github.com/m0-foundation/m-extensions/commit/7ed8340dcfdca31ae24c4d2ceca3bebb47798b04)

Reviewed contracts:

- `src/oracle/AggregatorV3Interface.sol`
- `src/oracle/NAVProxyMPriceFeed.sol`
- `src/usual/interfaces/IRegistryAccess.sol`
- `src/usual/interfaces/ISmartMLike.sol`
- `src/usual/interfaces/IUsualM.sol`
- `src/usual/constants.sol`
- `src/usual/UsualM.sol`

---

# Findings Summary

| ID     | Title                                                            | Severity      | Status       |
|--------|------------------------------------------------------------------|---------------|--------------|
| [H-01] | Incorrect decimals used for validating Chainlink oracle response | High          |              |
| [I-01] | Permit front-running causes revert in `wrapWithPermit`           | Informational | Acknowledged |
| [I-02] | Missing support for full balance wrapping via `wrapWithPermit`   | Informational | Acknowledged |
| [I-03] | Typos in NatSpec comments                                        | Informational |              |

# Security & Economic Findings

## [H-01] Incorrect decimals used for validating Chainlink oracle response

The default number of decimals for most Chainlink oracles is 8, which also applies to the newly deployed M NAV Chainlink
oracle available at `0xC28198Df9aee1c4990994B35ff51eFA4C769e534`. However, `NAVProxyMPriceFeed` incorrectly assumes the
Chainlink oracle has 6 decimals in `_getPriceFromNAV`. This may lead to incorrect values being reported by the proxy
oracle if the Chainlink NAV value drops below `1e8` (i.e., the proxy will keep reporting `1e6` instead of reporting
lower values).

### Recommendation

Update `NAVProxyMPriceFeed` decimals setting to 8 OR convert all values coming from the Chainlink's NAV oracle contract
from 8 decimals down to 6.

# Informational & Gas Optimizations

## [I-01] Permit front-running causes revert in `wrapWithPermit`

The function `wrapWithPermit` reverts if the underlying call to `permit` fails. The call to `permit` can be front-run by
anyone once the transaction with `wrapWithPermit` is spotted in the mempool. Also, since `transferFrom` would revert
anyway if no sufficient allowance is present, `permit` call failures can be safely ignored to remove the risk of
transactions being reverted due to front-run.

Consider adopting a `tryPermit` pattern (e.g., similar to the one used
in [1inch protocols](https://github.com/1inch/solidity-utils/blob/12763d675b6318779a3e578b5ba1be65aff164bc/contracts/libraries/SafeERC20.sol#L300)).

## [I-02] Missing support for full balance wrapping via `wrapWithPermit`

There is useful `wrap` functionality in `UsualM` that wraps all available balance, which greatly improves the UX for
rebasing tokens. However, no corresponding `wrapWithPermit` alternative exists.

Consider adding a similar `wrapWithPermit` overload that uses a `permit` signature to obtain an infinite allowance but
transfers only the available M Token balance.

## [I-03] Typos in NatSpec comments

In the `IUsualM.sol`:

```diff
-/// @notice Returns wheather account is blacklisted.
+/// @notice Returns whether account is blacklisted.
```
