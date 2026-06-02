// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NFTMintArena {
    address public owner;
    uint256 public mintPrice;
    uint256 public maxSupply;
    uint256 public totalMinted;

    mapping(address => uint256) public minted;
    mapping(uint256 => address) public ownerOf;

    bool private locked;

    event MintAttempt(address indexed user, uint256 value);
    event MintSuccess(address indexed user, uint256 tokenId);
    event RefundIssued(address indexed user, uint256 amount);
    event PriceChanged(uint256 oldPrice, uint256 newPrice);
    event Withdrawn(address indexed owner, uint256 amount);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor(uint256 _price, uint256 _maxSupply) {
        require(_price > 0, "Invalid price");
        require(_maxSupply > 0, "Invalid max supply");

        owner = msg.sender;
        mintPrice = _price;
        maxSupply = _maxSupply;
    }

    function mint() external payable nonReentrant {
        emit MintAttempt(msg.sender, msg.value);

        require(msg.value >= mintPrice, "Not enough ETH");
        require(totalMinted < maxSupply, "Sold out");

        uint256 tokenId = totalMinted + 1;

        minted[msg.sender] += 1;
        totalMinted += 1;
        ownerOf[tokenId] = msg.sender;

        uint256 refund = msg.value - mintPrice;
        if (refund > 0) {
            (bool refundOk,) = payable(msg.sender).call{value: refund}("");
            require(refundOk, "Refund failed");

            emit RefundIssued(msg.sender, refund);
        }

        emit MintSuccess(msg.sender, tokenId);
    }

    function changePrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Invalid price");

        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;

        emit PriceChanged(oldPrice, newPrice);
    }

    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        require(newOwner != owner, "Same owner");

        address oldOwner = owner;
        owner = newOwner;

        emit OwnerChanged(oldOwner, newOwner);
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        require(amount > 0, "No funds");

        (bool ok,) = payable(owner).call{value: amount}("");
        require(ok, "Withdraw failed");

        emit Withdrawn(owner, amount);
    }

    receive() external payable {
        revert("Direct ETH not accepted");
    }
}