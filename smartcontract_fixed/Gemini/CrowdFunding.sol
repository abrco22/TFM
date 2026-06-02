// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Crowdfunding {
    // --- ESTADO ---
    address public immutable owner;
    uint256 public immutable goal;
    uint256 public immutable deadline;
    uint256 public totalRaised;
    bool public ownerWithdrawn;

    mapping(address => uint256) public contributions;

    // --- EVENTOS ---
    event Contributed(address indexed contributor, uint256 amount);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);

    // --- MODIFICADORES ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor(uint256 _goal, uint256 _time) {
        require(_goal > 0, "Goal must be greater than zero");
        require(_time > 0, "Duration must be greater than zero");

        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _time;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Permite a cualquier usuario contribuir fondos a la campaña mientras esté activa.
     */
    function contribute() external payable {
        require(block.timestamp < deadline, "Crowdfunding campaign has ended");
        require(msg.value > 0, "Contribution must be greater than zero");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit Contributed(msg.sender, msg.value);
    }

    /**
     * @notice Permite al propietario retirar los fondos acumulados si se cumplió exitosamente la meta.
     */
    function withdrawAll() external onlyOwner {
        require(block.timestamp >= deadline, "Campaign is still active");
        require(totalRaised >= goal, "Funding goal was not reached");
        require(!ownerWithdrawn, "Funds already claimed by owner");

        // Efecto
        ownerWithdrawn = true;
        uint256 amount = address(this).balance;

        // Interacción
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "Transfer to owner failed");

        emit FundsWithdrawn(owner, amount);
    }

    /**
     * @notice Permite a los contribuyentes reclamar un reembolso íntegro si el proyecto fracasó.
     */
    function refund() external {
        require(block.timestamp >= deadline, "Campaign is still active");
        require(totalRaised < goal, "Funding goal was reached, cannot refund");

        uint256 amountToRefund = contributions[msg.sender];
        require(amountToRefund > 0, "No contributions found to refund");

        // Checks-Effects-Interactions: Modificar estado contable ANTES de la llamada externa
        contributions[msg.sender] = 0;

        // Interacción
        (bool ok, ) = payable(msg.sender).call{value: amountToRefund}("");
        require(ok, "Refund transfer failed");

        emit Refunded(msg.sender, amountToRefund);
    }
}