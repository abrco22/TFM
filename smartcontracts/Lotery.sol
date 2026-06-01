// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Lotery {
    address[] public players;

    function enter() external payable {
        require(msg.value == 0.01 ether);
        players.push(msg.sender);
    }

    function pick() external {
        require(players.length > 0);

        uint256 r =
            uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, msg.sender, players.length)
                )
            );

        address winner = players[r % players.length];

        (bool ok,) = payable(winner).call{value: address(this).balance}("");
        require(ok);

        delete players;
    }
}