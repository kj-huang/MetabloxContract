// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Metablox is ERC721URIStorage, Ownable {
    using SafeMath for uint256;
    
    event NewBlox(uint bloxId, uint bloxNumber, string name, uint tier, uint level, uint16 generation);

    uint256 public _owned_supply = 0;
    uint256 public our_total_supply;

    uint256 public phase = 1;
    uint[] price_tiers;
    mapping (uint => uint) price;

    address public usdt_address = address(0x7de63c1B50d2bD74a95De53D971a58aA48a87518);

    IERC20 public usdt;

    struct Blox {
        uint bloxNumber;
        string name;
        uint tier;
        uint level;
        uint16 generation;
    }
    Blox[] public bloxs;
    mapping (uint => address) public bloxToOwner;
    mapping (address => uint) public ownerBloxCount;

    constructor(uint total) public ERC721("Metablox", "Blox") {
        usdt = IERC20(usdt_address);

        our_total_supply = total;

        setPriceTiers();
    }

    function setPriceTiers() private {
        price_tiers.push(100);
        price_tiers.push(200);
        price_tiers.push(300);
        price_tiers.push(400);
        price_tiers.push(500);
    }

    /**
    * We send the reserve NFT to the player
    */
    function mintUniqueTokenTo(address player, string memory tokenURI, 
                                uint _bloxNumber, string memory _name, uint _tier, uint _level, 
                                uint16 _generation) public onlyOwner
        returns (uint256)
    {
        uint256 _tokenId = _owned_supply;
        _mint(player, _tokenId);
        _setTokenURI(_tokenId, tokenURI);

        Blox memory blox = Blox(_bloxNumber, _name, _tier, _level, _generation);
        bloxs.push(blox);

        bloxToOwner[_tokenId] = player;
        ownerBloxCount[player]++;

        emit NewBlox(_tokenId, _bloxNumber, _name, _tier, _level, _generation);

        _owned_supply = _owned_supply.add(1);

        return _tokenId;
    }

    function UpgradePhase() public onlyOwner {
        if(our_total_supply.mul(phase).div(10) == _owned_supply){
            phase = phase.add(1);
            uint const = 3;
            uint256 exp = const.div(5) ** phase;

            for(uint i = 0; i < price_tiers.length; i++)
                price_tiers[i] = price_tiers[i].mul(exp);
        }
    }

    function lookupPrice() public view returns(uint[] memory){
        return price_tiers;
    }

    function mintWithUSDT(uint256 _tokenId, string memory tokenURI, uint _amount, 
                            uint _bloxNumber, string memory _name, 
                            uint _tier, uint _level, 
                            uint16 _generation) external {
        
        require(price_tiers[ bloxs[_tokenId].tier - 1 ] >= _amount, "insufficient funds");

        usdt.transfer(address(this), _amount);

        mintUniqueTokenTo(msg.sender, tokenURI, _bloxNumber, _name, _tier, _level, _generation);
    }

    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a.mod(b) == 0 ? 0 : 1;
        return a.sub(b).add(c);
    }
}