// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NFTBazaar {
    address public seller;
    uint256 public price;

    mapping(uint256 => address) public ownerOf;

    function list(uint256 id, uint256 p) external {
        seller = msg.sender;
        price = p;
    }

    function buy(uint256 id) external payable {
        require(msg.value >= price);

        ownerOf[id] = msg.sender;

        (bool ok,) = payable(seller).call{value: msg.value}("");
        require(ok);
    }
}