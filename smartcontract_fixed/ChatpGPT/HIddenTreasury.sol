// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HiddenTreasury {
    address public owner;

    mapping(address => uint256) public balances;
    uint256 public totalLiabilities;

    bool private locked;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event TreasuryTransferred(address indexed target, uint256 amount);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        require(msg.value > 0, "No ETH sent");

        balances[msg.sender] += msg.value;
        totalLiabilities += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        totalLiabilities -= amount;

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function transferToTreasury(address target, uint256 amount) external onlyOwner nonReentrant {
        require(target != address(0), "Zero address");
        require(amount > 0, "Invalid amount");

        uint256 freeBalance = address(this).balance - totalLiabilities;
        require(freeBalance >= amount, "Insufficient treasury funds");

        (bool ok,) = payable(target).call{value: amount}("");
        require(ok, "Transfer failed");

        emit TreasuryTransferred(target, amount);
    }

    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        require(newOwner != owner, "Same owner");

        address oldOwner = owner;
        owner = newOwner;

        emit OwnerChanged(oldOwner, newOwner);
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        totalLiabilities += msg.value;

        emit Deposited(msg.sender, msg.value);
    }
}