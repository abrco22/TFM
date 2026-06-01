// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NFTMintArena {
    address public owner;
    uint256 public mintPrice;
    uint256 public maxSupply;
    uint256 public totalMinted;

    mapping(address => uint256) public minted;

    event MintAttempt(address indexed user, uint256 value);
    event MintSuccess(address indexed user, uint256 tokenId);

    constructor(uint256 _price, uint256 _maxSupply) {
        owner = msg.sender;
        mintPrice = _price;
        maxSupply = _maxSupply;
    }

    function mint() external payable {
        emit MintAttempt(msg.sender, msg.value);

        require(msg.value >= mintPrice, "Not enough ETH");
        require(totalMinted < maxSupply, "Sold out");

        uint256 tokenId = totalMinted + 1;

        minted[msg.sender] += 1;
        totalMinted += 1;

        emit MintSuccess(msg.sender, tokenId);
    }

    function changePrice(uint256 newPrice) external {
        require(msg.sender == owner, "Not owner");
        mintPrice = newPrice;
    }

    function withdraw() external {
        require(msg.sender == owner, "Not owner");

        (bool ok,) = payable(owner).call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }

    receive() external payable {}
}