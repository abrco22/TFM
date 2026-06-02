// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NFTMintArena (Patched)
 * @notice Contrato de mint de NFTs con distribución equitativa, contabilidad
 *         auditada, reembolso de overpayment, propiedad on-chain y ownership
 *         transferible.
 * @dev Fixes: V-01 (overpayment refund), V-02 (maxPerWallet), V-03 (price cap),
 *             V-04 (mintRevenue accounting), V-05 (receive event),
 *             V-06 (transferOwnership), V-07 (ownerOf mapping), V-08 (constructor guards).
 */
contract NFTMintArena {

    // ─── State Variables ──────────────────────────────────────────────────────

    address public owner;
    uint256 public mintPrice;
    uint256 public maxSupply;
    uint256 public totalMinted;

    /**
     * @notice Precio máximo al que el owner puede fijar el mint.
     * @dev    FIX V-03: evita que changePrice() pueda establecer precios
     *         arbitrariamente altos o bloqueantes.
     */
    uint256 public immutable maxMintPrice;

    /**
     * @notice Número máximo de NFTs que una wallet puede mintear.
     * @dev    FIX V-02: previene acaparamiento de supply por un único actor.
     */
    uint256 public maxPerWallet;

    /// @notice Cuántos NFTs ha minteado cada dirección en total
    mapping(address => uint256) public minted;

    /**
     * @notice Propietario on-chain de cada tokenId.
     * @dev    FIX V-07: registra la propiedad de forma verificable on-chain.
     */
    mapping(uint256 => address) public ownerOf;

    /**
     * @notice Ingresos acumulados por mints (excluye ETH de receive()).
     * @dev    FIX V-04: contabilidad separada para auditar ingresos reales.
     */
    uint256 public mintRevenue;

    // ─── Events ───────────────────────────────────────────────────────────────

    event MintAttempt(address indexed user, uint256 value);
    event MintSuccess(address indexed user, uint256 indexed tokenId);

    // FIX V-05 + V-06: nuevos eventos de trazabilidad
    event EthReceived(address indexed sender, uint256 amount);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event PriceChanged(uint256 oldPrice, uint256 newPrice);
    event RevenueWithdrawn(address indexed to, uint256 amount);

    // ─── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param _price       Precio inicial de mint en wei (> 0).
     * @param _maxSupply   Supply máximo de la colección (> 0).
     * @param _maxPerWallet Máximo de mints por wallet (> 0).
     * @param _maxMintPrice Techo de precio que el owner puede fijar (>= _price).
     */
    constructor(
        uint256 _price,
        uint256 _maxSupply,
        uint256 _maxPerWallet,
        uint256 _maxMintPrice
    ) {
        // FIX V-08: validación de parámetros de construcción
        require(_price > 0,          "Price must be > 0");
        require(_maxSupply > 0,      "Max supply must be > 0");
        require(_maxPerWallet > 0,   "Max per wallet must be > 0");
        require(_maxMintPrice >= _price, "Max price must be >= initial price");

        owner        = msg.sender;
        mintPrice    = _price;
        maxSupply    = _maxSupply;
        maxPerWallet = _maxPerWallet;
        maxMintPrice = _maxMintPrice;   // immutable: fijado para siempre
    }

    // ─── Mint Function ────────────────────────────────────────────────────────

    /**
     * @notice Mintea un NFT al caller si quedan tokens disponibles.
     * @dev    FIX V-01: reembolsa overpayment al final (CEI).
     *         FIX V-02: límite por wallet via maxPerWallet.
     *         FIX V-04: acumula mintPrice (no msg.value) en mintRevenue.
     *         FIX V-07: registra ownerOf[tokenId].
     */
    function mint() external payable {
        emit MintAttempt(msg.sender, msg.value);

        // ── Checks ────────────────────────────────────────────────────────────
        require(msg.value >= mintPrice,  "Not enough ETH");
        require(totalMinted < maxSupply, "Sold out");
        // FIX V-02: límite de mint por wallet
        require(
            minted[msg.sender] < maxPerWallet,
            "Wallet mint limit reached"
        );

        // ── Effects ───────────────────────────────────────────────────────────
        uint256 tokenId = totalMinted + 1;

        // FIX V-07: registrar propiedad on-chain
        ownerOf[tokenId] = msg.sender;

        minted[msg.sender] += 1;
        totalMinted        += 1;

        // FIX V-04: contabilizar solo el precio exacto, no msg.value completo
        mintRevenue += mintPrice;

        emit MintSuccess(msg.sender, tokenId);

        // ── Interactions ──────────────────────────────────────────────────────
        // FIX V-01: devolver exceso de pago DESPUÉS de actualizar estado
        uint256 excess = msg.value - mintPrice;
        if (excess > 0) {
            (bool refundOk,) = payable(msg.sender).call{value: excess}("");
            require(refundOk, "Refund failed");
        }
    }

    // ─── Owner Functions ──────────────────────────────────────────────────────

    /**
     * @notice Cambia el precio de mint dentro del rango permitido.
     * @dev    FIX V-03: newPrice no puede superar maxMintPrice ni ser 0.
     * @param newPrice Nuevo precio en wei (0 < newPrice <= maxMintPrice).
     */
    function changePrice(uint256 newPrice) external {
        require(msg.sender == owner, "Not owner");
        // FIX V-03: precio debe ser positivo y no superar el techo inmutable
        require(newPrice > 0,             "Price must be > 0");
        require(newPrice <= maxMintPrice, "Exceeds max allowed price");

        emit PriceChanged(mintPrice, newPrice);
        mintPrice = newPrice;
    }

    /**
     * @notice Retira los ingresos acumulados por mints al owner.
     * @dev    FIX V-04: usa mintRevenue en lugar de address(this).balance,
     *         separando ingresos auditados de ETH recibido por otras vías.
     *         CEI: mintRevenue = 0 antes del call externo.
     */
    function withdraw() external {
        require(msg.sender == owner, "Not owner");

        uint256 amount = mintRevenue;
        require(amount > 0, "No revenue to withdraw");

        // CEI: estado a 0 antes de la transferencia
        mintRevenue = 0;

        emit RevenueWithdrawn(owner, amount);

        (bool ok,) = payable(owner).call{value: amount}("");
        require(ok, "Withdraw failed");
    }

    /**
     * @notice Transfiere la propiedad del contrato a una nueva dirección.
     * @dev    FIX V-06: ownership transferible; zero-address check obligatorio.
     * @param newOwner Nueva dirección del owner (no puede ser address(0)).
     */
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Not owner");
        // FIX V-06: previene pérdida irrecuperable de ownership
        require(newOwner != address(0), "Invalid owner address");

        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ─── Receive ──────────────────────────────────────────────────────────────

    /**
     * @notice Acepta ETH directo sin acreditarlo como ingreso de mint.
     * @dev    FIX V-05: emite evento para trazabilidad; no modifica mintRevenue.
     */
    receive() external payable {
        // FIX V-05: registro on-chain de ETH recibido fuera del flujo de mint
        emit EthReceived(msg.sender, msg.value);
    }
}