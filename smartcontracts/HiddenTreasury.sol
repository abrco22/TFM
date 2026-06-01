// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HiddenTreasury {
    address public owner;

    mapping(address => uint256) public balances;

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        require(msg.value > 0, "No ETH sent");
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");

    }

    function transferToTreasury(address target, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        require(address(this).balance >= amount, "Not enough ETH");

        (bool ok,) = payable(target).call{value: amount}("");
        require(ok, "Transfer failed");

    }

    function changeOwner(address newOwner) external {
        require(msg.sender == owner, "Only owner");
        owner = newOwner;

    }

    receive() external payable {
        balances[msg.sender] += msg.value;
    }
}