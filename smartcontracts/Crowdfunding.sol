// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Crowdfunding {
    address public owner;
    uint256 public goal;
    uint256 public deadline;

    mapping(address => uint256) public contributions;

    constructor(uint256 _goal, uint256 _time) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _time;
    }

    function contribute() external payable {
        contributions[msg.sender] += msg.value;
    }

    function withdrawAll() external {
        require(msg.sender == owner, "Not owner");

        (bool ok,) = payable(owner).call{value: address(this).balance}("");
        require(ok, "Fail");
    }

    function refund() external {
        require(block.timestamp > deadline);

        (bool ok,) = payable(msg.sender).call{
            value: contributions[msg.sender]
        }("");
        require(ok, "Fail");
    }
}
