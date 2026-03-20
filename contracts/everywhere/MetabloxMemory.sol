// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/**
 * @title MetabloxMemory
 * @notice On-chain memory storage for Metablox NFTs.
 * @dev Allows NFT owners to attach memory URIs (images, media) to their tokens.
 *      The MetabloxEverywhere contract stores a reference to this contract's address
 *      but interacts with it through external calls from the application layer.
 *
 *      This is a simplified interface. The full implementation is deployed on Polygon.
 *
 *      See also: contracts/v1/Memories.sol for the original V1 implementation.
 */
contract MetabloxMemory {
    struct Memory {
        address owner;
        string uri;
        uint256 timestamp;
    }

    // tokenId => array of memories
    mapping(uint256 => Memory[]) public tokenMemories;

    // maximum memories per token
    uint8 public constant MAX_MEMORIES = 5;

    /**
     * @notice Adds a memory to a token.
     * @param _tokenId The NFT token ID
     * @param _uri     The memory URI (IPFS/Arweave link to media)
     */
    function addMemory(uint256 _tokenId, string memory _uri) external {
        require(
            tokenMemories[_tokenId].length < MAX_MEMORIES,
            "MetabloxMemory: max memories reached"
        );
        tokenMemories[_tokenId].push(
            Memory(msg.sender, _uri, block.timestamp)
        );
    }

    /**
     * @notice Returns all memories for a token.
     * @param _tokenId The NFT token ID
     * @return An array of Memory structs
     */
    function getMemories(uint256 _tokenId) external view returns (Memory[] memory) {
        return tokenMemories[_tokenId];
    }
}
