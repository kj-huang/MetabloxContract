// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint);
    function allowance(address tokenOwner, address spender) external view returns (uint);
    function transfer(address to, uint value) external view;
    function approve(address spender, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external;
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


contract MetabloxMarketPlace is Ownable{
    event TradeStatusChange(uint256 tradeCounter, bytes32 status);

    // whitelist events
    event WhitelistRequested(address indexed subscriber);
    event WhitelistApproved(address indexed subscriber);
    event WhitelistRejected(address indexed subscriber);

    //commissionFee events
    event CommissionFeeChanged(uint256 indexed newCommissionFee);

    enum WhitelistState{
        None,
        Pending,
        Approved,
        Rejected
    }

    struct Trade {
        address poster;
        uint256 item;
        uint256 price;
        bytes32 status; // Open, Executed, Cancelled
    }
    
    mapping(uint256 => Trade) public trades;
    mapping(address => WhitelistState) public Whitelists;

    uint256 tradeCounter;
    IERC20 public currencyToken;
    IERC721 public itemToken;

    uint256 public comissionFee;

    constructor (address _currencyTokenAddress, address _itemTokenAddress) public {
        currencyToken = IERC20(_currencyTokenAddress);
        itemToken = IERC721(_itemTokenAddress);
        tradeCounter = 0;
    }

    function openTrade(uint256 _item, uint256 _price)
        public
    {
        itemToken.transferFrom(msg.sender, address(this), _item);
        trades[tradeCounter] = Trade({
            poster: msg.sender,
            item: _item,
            price: _price,
            status: "Open"
        });
        tradeCounter += 1;
        emit TradeStatusChange(tradeCounter - 1, "Open");
    }
    
    function executeTrade(uint256 _trade)
        public
    {
        Trade memory trade = trades[_trade];
        require(trade.status == "Open", "Trade is not Open.");
        currencyToken.transferFrom(msg.sender, trade.poster, trade.price);
        itemToken.transferFrom(address(this), msg.sender, trade.item);
        trades[_trade].status = "Executed";
        emit TradeStatusChange(_trade, "Executed");
    }

    function cancelTrade(uint256 _trade)
        public
    {
        Trade memory trade = trades[_trade];
        require(
            msg.sender == trade.poster,
            "Trade can be cancelled only by poster."
        );
        require(trade.status == "Open", "Trade is not Open.");
        itemToken.transferFrom(address(this), trade.poster, trade.item);
        trades[_trade].status = "Cancelled";
        emit TradeStatusChange(_trade, "Cancelled");
    }

    /////////////// Whitelist management ///////////////
    
   function setWhitelist(address playerAddress, uint state) public onlyOwner {
        if(state == 1){
            Whitelists[playerAddress] = WhitelistState.Pending;
            emit WhitelistRequested(playerAddress);
        }

        if(state == 2){
            Whitelists[playerAddress] = WhitelistState.Approved;
            emit WhitelistApproved(playerAddress);
        }

        if(state == 3){
            Whitelists[playerAddress] = WhitelistState.Rejected;
            emit WhitelistRejected(playerAddress);
        }
   }


   function setComissionFee(uint256 newComissionFee) public onlyOwner {
        require(newComissionFee <= 1 ether, "error_invalidTxFee");
        comissionFee = newComissionFee;
        emit CommissionFeeChanged(comissionFee);
    }
}
