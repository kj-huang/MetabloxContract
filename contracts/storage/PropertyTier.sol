// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PropertyTier
 * @notice Manages blox pricing tiers across different phases.
 * @dev Each blox has a property tier (1-5) that determines its base price.
 *      As the contract progresses through phases (triggered by supply milestones),
 *      the base price for each tier increases.
 *
 *      The full implementation is deployed on Polygon and can be verified on PolygonScan.
 *      This file provides the interface used by MetabloxV2 and MetabloxEverywhere.
 */
contract PropertyTier is Ownable {
    // phase => tier => price (in USD, no decimals)
    mapping(uint256 => mapping(uint256 => uint256)) public bloxBasePrice;

    /**
     * @notice Returns the base price for a given phase and tier.
     * @param _phase The current supply phase (0-indexed, advances every 10% of supply sold)
     * @param _tier  The property tier (0-indexed: 0=Tier1, 1=Tier2, ..., 4=Tier5)
     * @return The base price in USD (whole units, e.g., 100 = $100)
     */
    function getBloxBasePrice(
        uint256 _phase,
        uint256 _tier
    ) external view returns (uint256) {
        return bloxBasePrice[_phase][_tier];
    }

    /**
     * @notice Sets the base price for a specific phase and tier. Owner only.
     * @param _phase The phase number
     * @param _tier  The tier number
     * @param _price The price in USD (whole units)
     */
    function setBloxBasePrice(
        uint256 _phase,
        uint256 _tier,
        uint256 _price
    ) external onlyOwner {
        bloxBasePrice[_phase][_tier] = _price;
    }
}
