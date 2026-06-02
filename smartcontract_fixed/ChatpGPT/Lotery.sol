// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Lotery {
    address public owner;
    address[] public players;

    uint256 public constant ENTRY_FEE = 0.01 ether;
    uint256 public roundPrize;
    bool private locked;

    mapping(address => bool) public entered;

    event Entered(address indexed player);
    event WinnerSelected(address indexed winner, uint256 amount);
    event PrizeClaimed(address indexed winner, uint256 amount);

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

    function enter() external payable {
        require(msg.value == ENTRY_FEE, "Invalid entry fee");
        require(!entered[msg.sender], "Already entered");

        entered[msg.sender] = true;
        players.push(msg.sender);
        roundPrize += msg.value;

        emit Entered(msg.sender);
    }

    function pick() external onlyOwner nonReentrant {
        require(players.length > 0, "No players");

        uint256 r =
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.prevrandao,
                        block.timestamp,
                        address(this),
                        players.length
                    )
                )
            );

        address winner = players[r % players.length];
        uint256 prize = roundPrize;

        for (uint256 i = 0; i < players.length; i++) {
            entered[players[i]] = false;
        }

        delete players;
        roundPrize = 0;

        (bool ok,) = payable(winner).call{value: prize}("");
        require(ok, "Prize transfer failed");

        emit WinnerSelected(winner, prize);
    }

    receive() external payable {
        revert("Direct ETH not accepted");
    }
}