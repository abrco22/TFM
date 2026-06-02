// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SecureVoteMultiSig {
    address[] public owners;
    uint256 public required;

    mapping(address => bool) public isOwner;
    mapping(bytes32 => mapping(address => bool)) public approvals;
    mapping(bytes32 => bool) public executed;

    bool private locked;

    event Approved(address indexed owner, bytes32 indexed txHash);
    event Executed(address indexed to, uint256 value, bytes32 indexed txHash);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor(address[] memory o, uint256 r) {
        require(o.length > 0, "No owners");
        require(r > 0 && r <= o.length, "Invalid required");

        for (uint256 i = 0; i < o.length; i++) {
            require(o[i] != address(0), "Zero owner");
            require(!isOwner[o[i]], "Duplicate owner");

            isOwner[o[i]] = true;
            owners.push(o[i]);
        }

        required = r;
    }

    function approve(bytes32 txHash) external onlyOwner {
        require(txHash != bytes32(0), "Invalid txHash");
        require(!executed[txHash], "Already executed");
        require(!approvals[txHash][msg.sender], "Already approved");

        approvals[txHash][msg.sender] = true;

        emit Approved(msg.sender, txHash);
    }

    function execute(address to, uint256 value, bytes32 txHash) external nonReentrant {
        require(to != address(0), "Zero target");
        require(txHash != bytes32(0), "Invalid txHash");
        require(!executed[txHash], "Already executed");
        require(txHash == keccak256(abi.encode(address(this), to, value)), "Hash mismatch");

        uint256 count;

        for (uint256 i = 0; i < owners.length; i++) {
            if (approvals[txHash][owners[i]]) {
                count++;
            }
        }

        require(count >= required, "Not enough approvals");
        require(address(this).balance >= value, "Insufficient balance");

        executed[txHash] = true;

        (bool ok,) = payable(to).call{value: value}("");
        require(ok, "Execution failed");

        emit Executed(to, value, txHash);
    }

    receive() external payable {}
}