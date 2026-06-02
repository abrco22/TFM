// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SafeVault {
    address public owner;

    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;

    bool private locked;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event TreasuryWithdrawn(address indexed owner, uint256 amount);

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

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        require(msg.value > 0, "No ETH sent");

        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(deposits[msg.sender] >= amount, "Insufficient deposit");

        deposits[msg.sender] -= amount;
        totalDeposits -= amount;

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Withdraw failed");

        emit Withdrawn(msg.sender, amount);
    }

    function adminWithdraw() external onlyOwner nonReentrant {
        uint256 surplus = address(this).balance - totalDeposits;
        require(surplus > 0, "No surplus");

        (bool ok,) = payable(owner).call{value: surplus}("");
        require(ok, "Admin withdraw failed");

        emit TreasuryWithdrawn(owner, surplus);
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

        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;

        emit Deposited(msg.sender, msg.value);
    }
}