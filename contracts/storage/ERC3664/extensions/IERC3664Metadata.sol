// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../IERC3664.sol";

/**
 * @title IERC3664Metadata
 * @notice Extended interface for ERC3664 with metadata query capabilities.
 */
interface IERC3664Metadata is IERC3664 {
    function textOf(uint256 _tokenId, uint256 _attrId) external view returns (bytes memory);
}
