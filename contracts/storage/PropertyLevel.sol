// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./ERC3664/ERC3664.sol";

/**
 * @title PropertyLevel
 * @notice Manages property-level attributes for Metablox NFTs using the ERC3664 attribute system.
 * @dev Each minted blox gets 4 default attributes attached via batchAttach():
 *      - Attr 1 (id=1): Level (default: 1)
 *      - Attr 2 (id=2): Experience (default: 0)
 *      - Attr 3 (id=3): Generation (default: 1)
 *      - Attr 4 (id=4): Points (default: 300)
 *
 *      The full implementation is deployed on Polygon and can be verified on PolygonScan.
 *      This file provides the interface used by MetabloxV2 and MetabloxEverywhere.
 */
contract PropertyLevel is ERC3664 {
    /**
     * @notice Attaches multiple attributes to a token in a single call.
     * @param _tokenId  The NFT token ID to attach attributes to
     * @param _attrIds  Array of attribute type IDs
     * @param _amounts  Array of attribute amounts (numeric values)
     * @param _texts    Array of text data for each attribute (can be empty bytes)
     */
    function batchAttach(
        uint256 _tokenId,
        uint256[] memory _attrIds,
        uint256[] memory _amounts,
        bytes[] memory _texts
    ) public virtual {
        require(
            _attrIds.length == _amounts.length && _attrIds.length == _texts.length,
            "PropertyLevel: arrays length mismatch"
        );

        for (uint256 i = 0; i < _attrIds.length; i++) {
            attach(_tokenId, _attrIds[i], _amounts[i], _texts[i]);
        }
    }
}
