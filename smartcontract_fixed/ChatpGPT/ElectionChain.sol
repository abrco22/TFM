// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ElectionChain {
    address public owner;

    mapping(address => bool) public registered;
    mapping(address => bool) public hasVoted;
    mapping(uint256 => uint256) public votes;

    uint256 public candidates;
    bool public votingOpen = true;

    event VoterRegistered(address indexed user);
    event VoteCast(address indexed voter, uint256 indexed candidateId);
    event VotingClosed();

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 _candidates) {
        require(_candidates > 0, "Invalid candidates");

        owner = msg.sender;
        candidates = _candidates;
    }

    function registerVoter(address user) external onlyOwner {
        require(user != address(0), "Zero address");
        require(!registered[user], "Already registered");
        require(!hasVoted[user], "Already voted");

        registered[user] = true;

        emit VoterRegistered(user);
    }

    function vote(uint256 candidateId) external {
        require(votingOpen, "Voting closed");
        require(registered[msg.sender], "Not registered");
        require(!hasVoted[msg.sender], "Already voted");
        require(candidateId < candidates, "Invalid candidate");

        hasVoted[msg.sender] = true;
        registered[msg.sender] = false;
        votes[candidateId]++;

        emit VoteCast(msg.sender, candidateId);
    }

    function reRegister(address user) external onlyOwner {
        require(user != address(0), "Zero address");
        require(!hasVoted[user], "Already voted");
        require(!registered[user], "Already registered");

        registered[user] = true;

        emit VoterRegistered(user);
    }

    function closeVoting() external onlyOwner {
        require(votingOpen, "Already closed");

        votingOpen = false;

        emit VotingClosed();
    }
}