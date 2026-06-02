// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract YieldStake {
    address public owner;

    mapping(address => uint256) public stake;
    uint256 public totalStake;

    bool private locked;

    event Deposited(address indexed user, uint256 amount);
    event RewardAdded(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
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

        stake[msg.sender] += msg.value;
        totalStake += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    function reward(address user) external payable onlyOwner {
        require(user != address(0), "Zero address");
        require(msg.value > 0, "No reward sent");

        stake[user] += msg.value;
        totalStake += msg.value;

        emit RewardAdded(user, msg.value);
    }

    function withdraw(uint256 a) external nonReentrant {
        require(a > 0, "Invalid amount");
        require(stake[msg.sender] >= a, "Insufficient stake");

        stake[msg.sender] -= a;
        totalStake -= a;

        (bool ok,) = payable(msg.sender).call{value: a}("");
        require(ok, "Transfer failed");

        emit Withdrawn(msg.sender, a);
    }

    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        require(newOwner != owner, "Same owner");

        address oldOwner = owner;
        owner = newOwner;

        emit OwnerChanged(oldOwner, newOwner);
    }

    receive() external payable {
        revert("Use deposit or reward");
    }
}