// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GovDAOCore {
    address public owner;

    address[] public members;
    mapping(address => bool) public isMember;

    event MemberJoined(address indexed member);
    event EtherWithdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function join() external {
        require(!isMember[msg.sender], "Already member");

        isMember[msg.sender] = true;
        members.push(msg.sender);

        emit MemberJoined(msg.sender);
    }

    function memberCount() public view returns (uint256) {
        return members.length;
    }

    function compute() external view returns (uint256) {
        uint256 n = members.length;

        if (n <= 1) {
            return 0;
        }

        unchecked {
            return n * n * (n - 1);
        }
    }

    function withdrawEther() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "No funds");

        (bool success,) = payable(owner).call{value: amount}("");
        require(success, "Transfer failed");

        emit EtherWithdrawn(owner, amount);
    }

    receive() external payable {}
}