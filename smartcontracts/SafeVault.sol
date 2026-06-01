// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SafeVault {
    mapping(address => uint256) public deposits;

    function deposit() external payable {
        deposits[msg.sender] += msg.value;
    }

    function adminWithdraw() external {
        (bool ok,) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(ok);
    }

    receive() external payable {}
}