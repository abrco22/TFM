// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HiddenTreasury {
    // --- ESTADO ---
    address public owner;
    uint256 public treasuryBalance;
    mapping(address => uint256) public balances;

    // --- EVENTOS ---
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event TreasuryTransferred(address indexed target, uint256 amount);
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);

    // --- MODIFICADORES ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor() {
        owner = msg.sender;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Permite a los usuarios depositar Ether en su cuenta personal.
     */
    function deposit() external payable {
        require(msg.value > 0, "No ETH sent");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Permite a los usuarios retirar sus propios fondos del contrato.
     */
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // Checks-Effects-Interactions (Efecto antes de interacción)
        balances[msg.sender] -= amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Permite al propietario transferir fondos exclusivos de la tesorería.
     * @dev Ya no puede tocar los balances internos asignados a los usuarios.
     */
    function transferToTreasury(address target, uint256 amount) external onlyOwner {
        require(target != address(0), "Cannot transfer to zero address");
        require(treasuryBalance >= amount, "Not enough ETH in treasury");

        // Efecto
        treasuryBalance -= amount;

        // Interacción
        (bool ok, ) = payable(target).call{value: amount}("");
        require(ok, "Transfer failed");

        emit TreasuryTransferred(target, amount);
    }

    /**
     * @notice Transfiere la propiedad del contrato a una nueva cuenta.
     */
    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner: zero address");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @notice Maneja el Ether enviado directamente al contrato, asignándolo al balance del emisor.
     */
    receive() external payable {
        if (msg.sender == owner) {
            // El Ether enviado directamente por el dueño incrementa la tesorería de la plataforma
            treasuryBalance += msg.value;
        } else {
            // El Ether enviado por usuarios comunes va a sus saldos personales correspondientes
            balances[msg.sender] += msg.value;
        }
        emit Deposited(msg.sender, msg.value);
    }
}
