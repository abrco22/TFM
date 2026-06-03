// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GovDAOCore_Proxy {
    address public implementation;
    address public governor;

    constructor(address impl) {
        implementation = impl;
        governor = msg.sender;
    }

    function upgradeTo(address newImplementation) external {
        implementation = newImplementation;
    }

    fallback() external payable {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

contract GovDAOCore_Logic {
    address public implementation;
    address public governor;
    mapping(address => uint256) public votingPower;

    function initialize(address initialGovernor) external {
        governor = initialGovernor;
    }

    function grantVotingPower(address member, uint256 amount) external {
        require(msg.sender == governor, "Only governor");
        votingPower[member] += amount;
    }
}
