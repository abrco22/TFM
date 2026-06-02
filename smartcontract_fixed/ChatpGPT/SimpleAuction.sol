// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract SimpleAuction {
    address public seller;
    uint256 public highestBid;
    address public highestBidder;

    bool public ended;
    bool private locked;

    mapping(address => uint256) public pendingReturns;

    event NewBid(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event RefundWithdrawn(address bidder, uint256 amount);

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller");
        _;
    }

    constructor() {
        seller = msg.sender;
    }

    function bid() external payable {
        require(!ended, "Auction ended");
        require(msg.value > highestBid, "Bid too low");

        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBid = msg.value;
        highestBidder = msg.sender;

        emit NewBid(msg.sender, msg.value);
    }

    function withdrawRefund() external nonReentrant {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No refund");

        pendingReturns[msg.sender] = 0;

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Refund failed");

        emit RefundWithdrawn(msg.sender, amount);
    }

    function endAuction() external onlySeller nonReentrant {
        require(!ended, "Auction already ended");
        require(highestBidder != address(0), "No bids");

        ended = true;

        uint256 amount = highestBid;
        highestBid = 0;

        (bool ok,) = payable(seller).call{value: amount}("");
        require(ok, "Transfer failed");

        emit AuctionEnded(highestBidder, amount);
    }

    receive() external payable {
        revert("Use bid");
    }
}