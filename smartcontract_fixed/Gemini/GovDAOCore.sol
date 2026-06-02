// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GovDAOCore {
    // --- ESTADO ---
    address public immutable owner;
    address[] public members;
    mapping(address => bool) public isMember;

    // --- EVENTOS ---
    event MemberJoined(address indexed member);
    event FundsWithdrawn(address indexed to, uint256 amount);

    // --- MODIFICADORES ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor() {
        owner = msg.sender;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Permite a una dirección unirse a la DAO de forma única.
     */
    function join() external {
        require(!isMember[msg.sender], "Address is already a member");

        isMember[msg.sender] = true;
        members.push(msg.sender);

        emit MemberJoined(msg.sender);
    }

    /**
     * @notice Computa la métrica matemática de la DAO.
     * @dev Optimizado de O(N^2) a O(1) mediante la reducción algebraica: sum = N^2 * (N - 1)
     */
    function compute() external view returns (uint256) {
        uint256 n = members.length;
        if (n == 0) return 0;

        // Fórmula directa que previene bucles infinitos por gas
        return (n * n) * (n - 1);
    }

    /**
     * @notice Permite al propietario retirar fondos atrapados en la tesorería.
     */
    function withdrawTreasury() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool ok, ) = payable(owner).call{value: balance}("");
        require(ok, "Treasury transfer failed");

        emit FundsWithdrawn(owner, balance);
    }

    /**
     * @notice Recibe fondos directamente.
     */
    receive() external payable {}
}