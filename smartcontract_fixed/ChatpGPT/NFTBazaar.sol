// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NFTBazaar {
    address public seller;
    uint256 public price;

    mapping(uint256 => address) public ownerOf;

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;

    bool private locked;

    event Minted(address indexed owner, uint256 indexed id);
    event Listed(address indexed seller, uint256 indexed id, uint256 price);
    event Bought(address indexed buyer, address indexed seller, uint256 indexed id, uint256 price);
    event Refunded(address indexed buyer, uint256 amount);

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    function mint(uint256 id) external {
        require(ownerOf[id] == address(0), "Already minted");

        ownerOf[id] = msg.sender;

        emit Minted(msg.sender, id);
    }

    function list(uint256 id, uint256 p) external {
        require(ownerOf[id] == msg.sender, "Not token owner");
        require(p > 0, "Invalid price");

        seller = msg.sender;
        price = p;

        listings[id] = Listing({
            seller: msg.sender,
            price: p,
            active: true
        });

        emit Listed(msg.sender, id, p);
    }

    function buy(uint256 id) external payable nonReentrant {
        Listing memory listing = listings[id];

        require(listing.active, "Not listed");
        require(msg.sender != listing.seller, "Seller cannot buy");
        require(msg.value >= listing.price, "Insufficient payment");
        require(ownerOf[id] == listing.seller, "Seller no longer owns token");

        delete listings[id];

        ownerOf[id] = msg.sender;

        uint256 refund = msg.value - listing.price;

        (bool paid,) = payable(listing.seller).call{value: listing.price}("");
        require(paid, "Seller payment failed");

        if (refund > 0) {
            (bool refunded,) = payable(msg.sender).call{value: refund}("");
            require(refunded, "Refund failed");

            emit Refunded(msg.sender, refund);
        }

        emit Bought(msg.sender, listing.seller, id, listing.price);
    }
}