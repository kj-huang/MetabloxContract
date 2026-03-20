// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/**
 * @title IERC3664
 * @notice Interface for the ERC3664 attribute system.
 * @dev ERC3664 is an attribute extension standard that allows NFTs to carry
 *      on-chain metadata in the form of typed attributes with numeric values and text data.
 *      See: https://eips.ethereum.org/EIPS/eip-3664
 */
interface IERC3664 {
    event AttributeCreated(uint256 indexed attrId, string name, string symbol, string uri);
    event AttributeAttached(uint256 indexed tokenId, uint256 indexed attrId, uint256 amount);
    event AttributeRemoved(uint256 indexed tokenId, uint256 indexed attrId);
    event AttributeUpdated(uint256 indexed tokenId, uint256 indexed attrId, uint256 amount);

    function name(uint256 _attrId) external view returns (string memory);
    function symbol(uint256 _attrId) external view returns (string memory);
    function attrURI(uint256 _attrId) external view returns (string memory);
    function balanceOf(uint256 _tokenId, uint256 _attrId) external view returns (uint256);
    function attach(uint256 _tokenId, uint256 _attrId, uint256 _amount, bytes memory _text) external;
    function remove(uint256 _tokenId, uint256 _attrId) external;
}
