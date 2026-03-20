// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";

contract BloxMemories {

    IERC721 public itemToken;

    struct BloxMemory {
        address owner;
        string tokenURI;
    }

    constructor (address _itemTokenAddress) public {
        itemToken = IERC721(_itemTokenAddress);
    }

    mapping(uint => mapping(address => mapping (uint => BloxMemory))) public playerToMemories;
    mapping(uint => mapping(address => uint)) public playerMemoriesLength;
    
    mapping(uint => address) recentOwner;

    /**
     * @dev This function let the recent Blox owner add the memory
    */
    function addBloxMemory(uint _tokenId, string memory _tokenURI) public {
        require(recentOwner[_tokenId] == msg.sender, "You are not the recent owner");
        require(playerMemoriesLength[_tokenId][msg.sender] < 5, "Maximum is five pictures");
        
        uint id = playerMemoriesLength[_tokenId][msg.sender];

        playerToMemories[_tokenId][msg.sender][id] = BloxMemory(msg.sender, _tokenURI);

        playerMemoriesLength[_tokenId][msg.sender] = playerMemoriesLength[_tokenId][msg.sender] + 1;
    }

    /**
     * @dev This function let the recent Blox owner modify the memory
    */
    function modifyBloxMemory(uint _idx, uint _tokenId, string memory _tokenURI) public {
        require(recentOwner[_tokenId] == msg.sender, "You are not the recent owner");
        require(_idx > 0, "Index should greater then five");
        require(_idx < playerMemoriesLength[_tokenId][msg.sender], "You don't have that too much picture");

        playerToMemories[_tokenId][msg.sender][_idx] = BloxMemory(msg.sender, _tokenURI);
    }



    //TODO make the tokenOwner more querible
    function setTokenOwner(uint _tokenId) public {
        playerMemoriesLength[_tokenId][msg.sender] = 0;
        recentOwner[_tokenId] = itemToken.ownerOf(_tokenId);
        // return itemToken.ownerOf(_tokenId);
    }
}