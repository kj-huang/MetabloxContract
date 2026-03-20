// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title BoxV2 - Proxy Pattern Demo (Version 2 — The Upgrade)
 * @author KJH (Kuan-Jung, Huang)
 * @notice Demonstrates what an upgraded implementation looks like.
 *
 * @dev UPGRADE FLOW:
 *      1. Deploy BoxV1 as the implementation, deploy proxy pointing to BoxV1
 *      2. Users interact with the proxy — data is stored in the proxy
 *      3. Deploy BoxV2 as a new implementation contract
 *      4. Call `upgradeTo(BoxV2_address)` on the proxy
 *      5. Now all calls through the proxy use BoxV2 logic, but storage stays intact
 *
 *      ┌────────────┐         ┌────────────────┐
 *      │   Proxy    │ ──╌╌╌►  │  BoxV1 (old)    │  ← no longer used
 *      │ (Storage)  │         └────────────────┘
 *      │ value = 42 │ ──────► ┌────────────────┐
 *      │            │         │  BoxV2 (new)    │  ← current implementation
 *      └────────────┘         │  store()        │
 *                             │  retrieve()     │
 *                             │  increment() ★  │  ← new function
 *                             └────────────────┘
 *
 *      STORAGE LAYOUT RULE:
 *      BoxV2 keeps `_value` in the same storage slot as BoxV1.
 *      New variables (`_lastUpdated`) are added AFTER existing ones.
 *      Never insert, remove, or reorder state variables from a previous version.
 *
 *      ┌──────────────────────────────────────────┐
 *      │ Storage Layout (must be preserved)       │
 *      ├──────────────────────────────────────────┤
 *      │ Slot N+0: _value       (from BoxV1) ✓   │
 *      │ Slot N+1: _lastUpdated (new in BoxV2) ✓  │
 *      │          ↑ appended, not inserted         │
 *      └──────────────────────────────────────────┘
 *
 *      ON-CHAIN TRANSPARENCY:
 *      When the owner calls `upgradeTo()`, an `Upgraded(address)` event is emitted
 *      by the ERC1967 proxy. This event is visible on block explorers, so users and
 *      auditors can see that an upgrade occurred and inspect the new implementation.
 *      The existing data on-chain remains unchanged — only the logic changes.
 *
 *      Read more: https://mybaseball52.medium.com/will-proxy-pattern-design-become-a-poison-to-smart-contracts-1b6663913fd1
 */
contract BoxV2 is OwnableUpgradeable, UUPSUpgradeable {
    // ─── State Variables ───────────────────────────────────────────────
    // MUST match BoxV1's layout exactly (same order, same types)
    uint256 private _value;

    // NEW in V2: added after existing variables (safe to append)
    uint256 private _lastUpdated;

    // ─── Events ────────────────────────────────────────────────────────
    event ValueChanged(uint256 newValue);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Stores a new value and records the timestamp.
     * @param newValue The value to store
     */
    function store(uint256 newValue) public {
        _value = newValue;
        _lastUpdated = block.timestamp;
        emit ValueChanged(newValue);
    }

    /**
     * @notice Returns the stored value.
     */
    function retrieve() public view returns (uint256) {
        return _value;
    }

    /**
     * @notice NEW in V2: Increments the stored value by 1.
     * @dev This function did not exist in BoxV1. After upgrading the proxy to BoxV2,
     *      users can call this new function while retaining the value stored via BoxV1.
     */
    function increment() public {
        _value += 1;
        _lastUpdated = block.timestamp;
        emit ValueChanged(_value);
    }

    /**
     * @notice Returns when the value was last updated.
     * @dev NEW in V2. Returns 0 for values set via BoxV1 (before this field existed).
     */
    function lastUpdated() public view returns (uint256) {
        return _lastUpdated;
    }

    /**
     * @notice Returns the contract version string.
     */
    function version() public pure returns (string memory) {
        return "2.0.0";
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
