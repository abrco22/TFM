// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SecureVoteMultiSig {
    address[] public owners;
    uint256 public required;

    mapping(bytes32 => mapping(address => bool)) public approvals;

    constructor(address[] memory o, uint256 r) {
        owners = o;
        required = r;
    }

    function approve(bytes32 txHash) external {
        approvals[txHash][msg.sender] = true;
    }

    function execute(address to, uint256 value, bytes32 txHash) external {
        uint256 count;

        for (uint i = 0; i < owners.length; i++) {
            if (approvals[txHash][owners[i]]) {
                count++;
            }
        }

        require(count >= required);

        (bool ok,) = payable(to).call{value: value}("");
        require(ok);
    }
}