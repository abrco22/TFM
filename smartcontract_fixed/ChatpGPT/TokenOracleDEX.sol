// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TokenOracleDEX {
    mapping(address => uint256) public balances;
    uint256 public price;
    address public owner;

    bool private locked;

    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event Bought(address indexed buyer, uint256 ethIn, uint256 tokensOut);
    event Sold(address indexed seller, uint256 tokensIn, uint256 ethOut);
    event Funded(address indexed sender, uint256 amount);
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

    constructor(uint256 initialPrice) {
        require(initialPrice > 0, "Invalid price");

        owner = msg.sender;
        price = initialPrice;
    }

    function setPrice(uint256 p) external onlyOwner {
        require(p > 0, "Invalid price");

        uint256 oldPrice = price;
        price = p;

        emit PriceUpdated(oldPrice, p);
    }

    function buy() external payable {
        require(msg.value > 0, "No ETH sent");
        require(price > 0, "Invalid price");

        uint256 tokens = msg.value * price;
        require(tokens > 0, "Zero tokens");

        balances[msg.sender] += tokens;

        emit Bought(msg.sender, msg.value, tokens);
    }

    function sell(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(price > 0, "Invalid price");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        uint256 eth = amount / price;
        require(eth > 0, "Amount too small");
        require(address(this).balance >= eth, "Insufficient ETH liquidity");

        balances[msg.sender] -= amount;

        (bool ok,) = payable(msg.sender).call{value: eth}("");
        require(ok, "ETH transfer failed");

        emit Sold(msg.sender, amount, eth);
    }

    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        require(newOwner != owner, "Same owner");

        address oldOwner = owner;
        owner = newOwner;

        emit OwnerChanged(oldOwner, newOwner);
    }

    receive() external payable {
        require(msg.value > 0, "No ETH sent");

        emit Funded(msg.sender, msg.value);
    }
}