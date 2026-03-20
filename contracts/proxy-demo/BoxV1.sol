// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title BoxV1 - Proxy Pattern Demo (Version 1)
 * @author KJH (Kuan-Jung, Huang)
 * @notice A minimal example demonstrating the UUPS (Universal Upgradeable Proxy Standard) pattern.
 *
 * @dev WHY PROXY PATTERN?
 *      Smart contracts on the blockchain are immutable by design. Once deployed, their code
 *      cannot be changed. The proxy pattern solves this by separating storage from logic:
 *
 *      ┌────────────┐         ┌────────────────┐
 *      │   Proxy    │ ──────► │  BoxV1 (Logic)  │
 *      │ (Storage)  │         │  store()        │
 *      │ value = 42 │         │  retrieve()     │
 *      └────────────┘         └────────────────┘
 *
 *      The proxy contract holds the data (storage) and delegates all function calls to the
 *      logic contract (implementation). When you want to upgrade, you deploy a new logic
 *      contract and point the proxy to it — the storage remains unchanged.
 *
 *      KEY CONSTRAINTS:
 *      1. Use `initialize()` instead of `constructor` — constructors don't work with proxies
 *         because the constructor runs in the implementation's context, not the proxy's.
 *      2. Storage layout must be preserved across upgrades — you can only ADD new state
 *         variables at the end, never reorder or remove existing ones.
 *      3. The `_authorizeUpgrade` function controls who can perform upgrades.
 *
 *      TRANSPARENCY:
 *      While the proxy pattern allows upgrading logic, it does NOT allow modifying data
 *      that's already on-chain. Upgrade events are recorded on-chain and visible on block
 *      explorers like PolygonScan, maintaining a degree of transparency.
 *
 *      Read more: https://mybaseball52.medium.com/will-proxy-pattern-design-become-a-poison-to-smart-contracts-1b6663913fd1
 *
 *      METABLOX USAGE:
 *      The MetabloxEverywhere and MetabloxV2WithAccessControl contracts both use the UUPS
 *      pattern. This allows the team to fix bugs and add features to the NFT contracts
 *      without requiring users to migrate their tokens to a new contract address.
 */
contract BoxV1 is OwnableUpgradeable, UUPSUpgradeable {
    // ─── State Variables ───────────────────────────────────────────────
    // IMPORTANT: Once deployed, this variable's storage slot (slot 0 after inherited slots)
    // is permanently assigned. Future versions MUST keep this variable in the same position.
    uint256 private _value;

    // ─── Events ────────────────────────────────────────────────────────
    event ValueChanged(uint256 newValue);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Prevents the implementation contract from being initialized directly.
        // Only the proxy should call initialize().
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract. Called once during proxy deployment.
     * @dev Replaces the constructor. Uses the `initializer` modifier from OpenZeppelin
     *      to ensure it can only be called once (preventing re-initialization attacks).
     * @param initialValue The initial value to store
     */
    function initialize(uint256 initialValue) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        _value = initialValue;
    }

    /**
     * @notice Stores a new value.
     * @param newValue The value to store
     */
    function store(uint256 newValue) public {
        _value = newValue;
        emit ValueChanged(newValue);
    }

    /**
     * @notice Returns the stored value.
     * @return The current stored value
     */
    function retrieve() public view returns (uint256) {
        return _value;
    }

    /**
     * @notice Returns the contract version string.
     * @dev This helps verify which implementation version the proxy is pointing to.
     */
    function version() public pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * @dev Required by UUPS pattern. Only the owner can authorize upgrades.
     *      This is the security gate — without this check, anyone could point
     *      the proxy to a malicious implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
