// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VaultBank {
    // --- ESTADO ---
    mapping(address => uint256) public balances;
    address public immutable owner;
    
    // Estado interno para el control de reentrada
    uint8 private unlocked = 1;

    // --- EVENTOS ---
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    // --- MODIFICADORES ---
    modifier nonReentrant() {
        require(unlocked == 1, "ReentrancyGuard: reentrant call");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // --- CONSTRUCTOR ---
    constructor() {
        owner = msg.sender;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Permite a los usuarios depositar Ether de manera segura en el banco.
     */
    function deposit() external payable {
        require(msg.value > 0, "Cannot deposit zero Ether");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Permite a los usuarios retirar sus fondos del banco utilizando el patrón seguro CEI.
     * @param amount Cantidad de wei a retirar.
     */
    function withdraw(uint256 amount) external nonReentrant {
        // 1. CHECKS (Validaciones)
        require(amount > 0, "Amount must be greater than zero");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // 2. EFFECTS (Modificar el estado contable ANTES de transferir)
        balances[msg.sender] -= amount;

        // 3. INTERACTIONS (Llamada externa externa)
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Redirige las transferencias directas de Ether al método de depósito estándar.
     */
    receive() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }
}
