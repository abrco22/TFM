// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract SimpleAuction {
    address public seller;
    uint256 public highestBid;
    address public highestBidder;

    bool public ended;

    event NewBid(address bidder, uint256 amount);

    constructor() {
        seller = msg.sender;
    }

    function bid() external payable {
        require(!ended, "Auction ended");
        require(msg.value > highestBid, "Bid too low");

        highestBid = msg.value;
        highestBidder = msg.sender;

        emit NewBid(msg.sender, msg.value);
    }

    function endAuction() external {
        require(msg.sender == seller, "Only seller");
        ended = true;

        (bool ok,) = payable(seller).call{value: highestBid}("");
        require(ok, "Transfer failed");
    }

    receive() external payable {}
}