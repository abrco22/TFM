// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SafeVault {
    // --- ESTADO ---
    address public immutable owner;
    mapping(address => uint256) public deposits;

    // --- EVENTOS ---
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event AdminWithdrawn(address indexed admin, uint256 amount);

    // --- MODIFICADORES ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized: Only owner");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor() {
        owner = msg.sender;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Permite a los usuarios depositar Ether en su balance personal dentro de la bóveda.
     */
    function deposit() external payable {
        require(msg.value > 0, "Cannot deposit zero Ether");
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Permite a los usuarios retirar sus propios fondos depositados.
     * @param amount Cantidad de wei a retirar.
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(deposits[msg.sender] >= amount, "Insufficient balance");

        // Checks-Effects-Interactions: Modificar el balance antes de la llamada externa
        deposits[msg.sender] -= amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "User withdrawal failed");

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Permite exclusivamente al propietario retirar fondos adicionales o de tesorería de la bóveda.
     */
    function adminWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available in vault");

        (bool ok, ) = payable(owner).call{value: balance}("");
        require(ok, "Admin withdrawal failed");

        emit AdminWithdrawn(owner, balance);
    }

    /**
     * @notice Redirige las transferencias directas de Ether al flujo de depósito contable.
     */
    receive() external payable {
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }
}
