// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TokenOracleDEX {
    // --- ESTADO ---
    address public owner;
    uint256 public price;
    mapping(address => uint256) public balances;

    // --- EVENTOS ---
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event TokensPurchased(address indexed buyer, uint256 ethSpent, uint256 tokensReceived);
    event TokensSold(address indexed seller, uint256 tokensBurned, uint256 ethReceived);

    // --- MODIFICADORES ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized: Only owner");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor(uint256 _initialPrice) {
        require(_initialPrice > 0, "Price cannot be zero");
        owner = msg.sender;
        price = _initialPrice;
    }

    // --- FUNCIONES ADMINISTRATIVAS ---

    /**
     * @notice Permite actualizar el precio del token frente al Ether.
     * @param p Nuevo valor del precio (debe ser mayor a cero).
     */
    function setPrice(uint256 p) external onlyOwner {
        require(p > 0, "Price cannot be zero");
        emit PriceUpdated(price, p);
        price = p;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Compra tokens enviando Ether al contrato.
     */
    function buy() external payable {
        require(msg.value > 0, "Must send Ether to buy");
        
        uint256 tokenAmount = msg.value * price;
        balances[msg.sender] += tokenAmount;

        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }

    /**
     * @notice Vende tokens para retirar su equivalente en Ether.
     * @param amount Cantidad de tokens que se desean vender.
     */
    function sell(uint256 amount) external {
        // 1. CHECKS (Validaciones)
        require(amount > 0, "Amount must be greater than zero");
        require(balances[msg.sender] >= amount, "Insufficient token balance");

        uint256 ethAmount = amount / price;
        require(ethAmount > 0, "Token amount too low to convert to Ether");
        require(address(this).balance >= ethAmount, "Insufficient DEX liquidity");

        // 2. EFFECTS (Actualización de Estado - Previene Reentrancy)
        balances[msg.sender] -= amount;

        // 3. INTERACTIONS (Llamada externa externa de bajo nivel)
        (bool ok, ) = payable(msg.sender).call{value: ethAmount}("");
        require(ok, "Ether transfer failed");

        emit TokensSold(msg.sender, amount, ethAmount);
    }

    /**
     * @notice Permite recibir Ether directamente para fondear la liquidez de la DEX.
     */
    receive() external payable {}
}