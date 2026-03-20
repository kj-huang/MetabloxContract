// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./IERC3664.sol";
import "./extensions/IERC3664Metadata.sol";

/**
 * @title ERC3664
 * @notice Implementation of the ERC3664 attribute system for composable NFT metadata.
 * @dev This standard allows attaching typed attributes (with numeric values and optional text)
 *      to any NFT token ID. Attributes are created with a name, symbol, and URI, then
 *      attached to tokens. Used by PropertyLevel to manage blox attributes.
 *
 *      The full implementation is deployed on Polygon and can be verified on PolygonScan.
 */
contract ERC3664 is IERC3664 {
    struct AttrMetadata {
        string name;
        string symbol;
        string uri;
        bool exists;
    }

    // attrId => metadata
    mapping(uint256 => AttrMetadata) private _attrMetadata;
    // tokenId => attrId => amount
    mapping(uint256 => mapping(uint256 => uint256)) private _balances;
    // tokenId => attrId => text
    mapping(uint256 => mapping(uint256 => bytes)) private _texts;
    // tokenId => attrId => attached
    mapping(uint256 => mapping(uint256 => bool)) private _attached;

    uint256 private _attrCount;

    function create(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) public virtual returns (uint256) {
        _attrCount++;
        _attrMetadata[_attrCount] = AttrMetadata(_name, _symbol, _uri, true);
        emit AttributeCreated(_attrCount, _name, _symbol, _uri);
        return _attrCount;
    }

    function name(uint256 _attrId) external view override returns (string memory) {
        return _attrMetadata[_attrId].name;
    }

    function symbol(uint256 _attrId) external view override returns (string memory) {
        return _attrMetadata[_attrId].symbol;
    }

    function attrURI(uint256 _attrId) external view override returns (string memory) {
        return _attrMetadata[_attrId].uri;
    }

    function balanceOf(uint256 _tokenId, uint256 _attrId) external view override returns (uint256) {
        return _balances[_tokenId][_attrId];
    }

    function textOf(uint256 _tokenId, uint256 _attrId) external view returns (bytes memory) {
        return _texts[_tokenId][_attrId];
    }

    function attach(
        uint256 _tokenId,
        uint256 _attrId,
        uint256 _amount,
        bytes memory _text
    ) public virtual override {
        _balances[_tokenId][_attrId] = _amount;
        _texts[_tokenId][_attrId] = _text;
        _attached[_tokenId][_attrId] = true;
        emit AttributeAttached(_tokenId, _attrId, _amount);
    }

    function remove(uint256 _tokenId, uint256 _attrId) public virtual override {
        delete _balances[_tokenId][_attrId];
        delete _texts[_tokenId][_attrId];
        _attached[_tokenId][_attrId] = false;
        emit AttributeRemoved(_tokenId, _attrId);
    }
}
