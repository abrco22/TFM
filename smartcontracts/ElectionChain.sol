// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ElectionChain {
    mapping(address => bool) public registered;
    mapping(uint256 => uint256) public votes;

    uint256 public candidates;

    constructor(uint256 _candidates) {
        candidates = _candidates;
    }

    function registerVoter(address user) external {
        registered[user] = true;
    }

    function vote(uint256 candidateId) external {
        require(registered[msg.sender], "Not registered");
        require(candidateId < candidates, "Invalid candidate");

        votes[candidateId]++;

        registered[msg.sender] = false;
    }

    function reRegister(address user) external {
        registered[user] = true;
    }
}