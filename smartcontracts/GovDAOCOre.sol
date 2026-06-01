// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GovDAOCore {
    address[] public members;

    function join() external {
        members.push(msg.sender);
    }

    function compute() external view returns (uint256) {
        uint256 sum;

        for (uint i = 0; i < members.length; i++) {
            for (uint j = 0; j < members.length; j++) {
                sum += i + j;
            }
        }

        return sum;
    }

    receive() external payable {}
}