// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract YieldStake {
    mapping(address => uint256) public stake;

    function deposit() external payable {
        stake[msg.sender] += msg.value;
    }

    function reward(uint256 r) external {
        stake[msg.sender] += r;
    }

    function withdraw(uint256 a) external {
        require(stake[msg.sender] >= a);

        stake[msg.sender] -= a;

        (bool ok,) = payable(msg.sender).call{value: a}("");
        require(ok);
    }
}