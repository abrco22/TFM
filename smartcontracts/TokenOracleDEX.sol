// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TokenOracleDEX {
    mapping(address => uint256) public balances;
    uint256 public price;

    function setPrice(uint256 p) external {
        price = p;
    }

    function buy() external payable {
        balances[msg.sender] += msg.value * price;
    }

    function sell(uint256 amount) external {
        uint256 eth = amount / price;

        (bool ok,) = payable(msg.sender).call{value: eth}("");
        require(ok);

        balances[msg.sender] -= amount;
    }
}