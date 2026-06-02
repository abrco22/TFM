// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Crowdfunding {
    address public owner;
    uint256 public goal;
    uint256 public deadline;

    mapping(address => uint256) public contributions;

    bool private locked;
    bool public withdrawn;

    event Contributed(address indexed contributor, uint256 amount);
    event Withdrawn(address indexed owner, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);

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

    constructor(uint256 _goal, uint256 _time) {
        require(_goal > 0, "Invalid goal");
        require(_time > 0, "Invalid time");

        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _time;
    }

    function contribute() external payable {
        require(block.timestamp <= deadline, "Campaign ended");
        require(msg.value > 0, "Zero contribution");

        contributions[msg.sender] += msg.value;

        emit Contributed(msg.sender, msg.value);
    }

    function withdrawAll() external onlyOwner nonReentrant {
        require(block.timestamp > deadline, "Campaign active");
        require(address(this).balance >= goal, "Goal not reached");
        require(!withdrawn, "Already withdrawn");

        uint256 amount = address(this).balance;
        withdrawn = true;

        (bool ok,) = payable(owner).call{value: amount}("");
        require(ok, "Transfer failed");

        emit Withdrawn(owner, amount);
    }

    function refund() external nonReentrant {
        require(block.timestamp > deadline, "Campaign active");
        require(address(this).balance < goal, "Goal reached");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution");

        contributions[msg.sender] = 0;

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");

        emit Refunded(msg.sender, amount);
    }
}