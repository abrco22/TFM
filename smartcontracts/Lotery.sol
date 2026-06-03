// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Lotery {
    address[] public players;
    mapping(address => uint256) public tickets;

    uint256 public ticketPrice = 0.01 ether;

    function buyTickets() external payable {
        require(msg.value >= ticketPrice, "Not enough ETH");
        uint256 count = msg.value / ticketPrice;
        tickets[msg.sender] += count;
        players.push(msg.sender);
    }

    function drawWinner(uint256 randomness) external view returns (address) {
        require(players.length > 0, "No players");

        uint256 poolWeight = address(this).balance / ticketPrice;
        uint256 index = randomness % poolWeight;

        return players[index % players.length];
    }

    receive() external payable {}
}
