// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VaultBank {
    mapping(address => uint256) public balances;
    address public owner;

    bool private locked;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

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

        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    receive() external payable {
        require(msg.value > 0, "No ETH sent");

        balances[msg.sender] += msg.value;

        emit Deposited(msg.sender, msg.value);
    }
}