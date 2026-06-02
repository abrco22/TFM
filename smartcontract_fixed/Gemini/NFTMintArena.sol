// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NFTMintArena {
    // --- ESTADO ---
    address public immutable owner;
    uint256 public mintPrice;
    uint256 public immutable maxSupply;
    uint256 public totalMinted;

    mapping(address => uint256) public minted;

    // --- EVENTOS ---
    event MintAttempt(address indexed user, uint256 value);
    event MintSuccess(address indexed user, uint256 indexed tokenId);
    event PriceChanged(uint256 oldPrice, uint256 newPrice);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    // --- MODIFICADORES ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized: Only owner");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor(uint256 _price, uint256 _maxSupply) {
        require(_maxSupply > 0, "Max supply must be greater than zero");
        owner = msg.sender;
        mintPrice = _price;
        maxSupply = _maxSupply;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Ejecuta el minado de un NFT devolviendo el dinero excedente al usuario de forma automática.
     */
    function mint() external payable {
        emit MintAttempt(msg.sender, msg.value);

        // 1. CHECKS
        require(msg.value >= mintPrice, "Not enough ETH sent");
        require(totalMinted < maxSupply, "Sold out");

        // Guardar precio actual en memoria para optimizar gas y mitigar front-running parcial
        uint256 currentPrice = mintPrice; 

        // 2. EFFECTS
        totalMinted += 1;
        uint256 tokenId = totalMinted;
        minted[msg.sender] += 1;

        // 3. INTERACTIONS (Patrón Checks-Effects-Interactions)
        // Devolución del excedente si el usuario envió Ether de más
        uint256 excessAmount = msg.value - currentPrice;
        if (excessAmount > 0) {
            (bool refundOk, ) = payable(msg.sender).call{value: excessAmount}("");
            require(refundOk, "Refund of excess ETH failed");
        }

        emit MintSuccess(msg.sender, tokenId);
    }

    // --- FUNCIONES ADMINISTRATIVAS ---

    /**
     * @notice Cambia el precio de acuñación del NFT.
     * @dev Se recomienda emitir un evento previo off-chain para evitar ataques Sandwich a los usuarios.
     * @param newPrice Nuevo precio en wei.
     */
    function changePrice(uint256 newPrice) external onlyOwner {
        emit PriceChanged(mintPrice, newPrice);
        mintPrice = newPrice;
    }

    /**
     * @notice Retira de forma segura la recaudación del contrato hacia la cuenta del propietario.
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool ok, ) = payable(owner).call{value: balance}("");
        require(ok, "Withdraw failed");

        emit FundsWithdrawn(owner, balance);
    }
}