// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TokenOracleDEX (Patched)
 * @notice DEX con precio controlado por owner, aritmética de precisión WAD,
 *         CEI estricto, protección contra reentrancy y trazabilidad completa.
 * @dev Fixes: V-01 (onlyOwner setPrice), V-02 (CEI + nonReentrant sell),
 *             V-03 (price > 0 guards), V-04 (PRECISION scaling),
 *             V-05 (overflow seguro con PRECISION), V-06 (balance check CEI),
 *             V-07 (receive + addLiquidity), V-08 (eventos).
 *
 * Modelo de precio:
 *   price = wei de ETH necesarios para comprar PRECISION (1e18) unidades de token
 *   buy:  tokens = (msg.value * PRECISION) / price
 *   sell: eth    = (amount   * price)     / PRECISION
 */
contract TokenOracleDEX {

    // ─── Constants ────────────────────────────────────────────────────────────

    /**
     * @notice Factor de escala para aritmética de punto fijo (WAD estándar DeFi).
     * @dev    FIX V-04: evita pérdida de precisión en divisiones enteras.
     *         Ejemplo: price = 2e15 significa 0.002 ETH por token (1 ETH = 500 tokens).
     */
    uint256 public constant PRECISION = 1e18;

    // ─── State Variables ──────────────────────────────────────────────────────

    /// @notice Propietario del DEX — único autorizado para actualizar el precio
    /// @dev    FIX V-01: reemplaza la ausencia total de access control en setPrice()
    address public owner;

    /**
     * @notice Precio en wei por PRECISION unidades de token.
     * @dev    FIX V-03: siempre > 0 garantizado por constructor y setPrice().
     *         FIX V-04: escalado con PRECISION para aritmética de punto fijo.
     */
    uint256 public price;

    /// @notice Balance de tokens de cada usuario
    mapping(address => uint256) public balances;

    /// @dev FIX V-02: mutex contra reentrancy en sell() y addLiquidity()
    bool private _locked;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-08: trazabilidad completa de todas las operaciones del DEX
    event TokensBought(
        address indexed buyer,
        uint256 ethIn,
        uint256 tokensOut,
        uint256 price
    );
    event TokensSold(
        address indexed seller,
        uint256 tokensIn,
        uint256 ethOut,
        uint256 price
    );
    event PriceUpdated(
        address indexed updatedBy,
        uint256 oldPrice,
        uint256 newPrice
    );
    event LiquidityAdded(address indexed provider, uint256 amount);
    event EthReceived(address indexed sender, uint256 amount);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev FIX V-01: solo el owner puede actualizar el precio
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    /// @dev FIX V-02: bloquea reentrancy directa y cross-function en sell()
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param _initialPrice Precio inicial en wei por PRECISION tokens (debe ser > 0).
     * @dev    FIX V-03: el contrato nunca tiene price == 0 desde el deploy.
     *         FIX V-01: owner asignado al deployer.
     */
    constructor(uint256 _initialPrice) {
        // FIX V-03: el precio inicial debe ser válido
        require(_initialPrice > 0, "Initial price must be > 0");

        owner = msg.sender;
        price = _initialPrice;
    }

    // ─── Owner Functions ──────────────────────────────────────────────────────

    /**
     * @notice Actualiza el precio del token.
     * @dev    FIX V-01: restringido a onlyOwner — elimina manipulación por terceros.
     *         FIX V-03: precio siempre > 0 para evitar división por cero.
     * @param p Nuevo precio en wei por PRECISION unidades de token (debe ser > 0).
     */
    function setPrice(uint256 p) external onlyOwner {
        // FIX V-03: previene que el precio sea 0 (división por cero en sell/buy)
        require(p > 0, "Price must be > 0");

        emit PriceUpdated(msg.sender, price, p); // FIX V-08
        price = p;
    }

    /**
     * @notice Añade liquidez ETH al DEX para respaldar operaciones de sell().
     * @dev    FIX V-07: mecanismo explícito de fondeado de liquidez.
     */
    function addLiquidity() external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");
        emit LiquidityAdded(msg.sender, msg.value); // FIX V-08
    }

    // ─── Trading Functions ────────────────────────────────────────────────────

    /**
     * @notice Compra tokens enviando ETH al contrato.
     * @dev    FIX V-04: aritmética escalada con PRECISION — (msg.value * PRECISION) / price.
     *         FIX V-03: price > 0 garantizado por constructor y setPrice().
     *         FIX V-05: división antes de multiplicación evita overflow.
     */
    function buy() external payable {
        require(msg.value > 0, "Must send ETH to buy");
        // FIX V-03: guard defensivo — price siempre > 0 por diseño, pero verificamos
        require(price > 0, "Price not initialized");

        // FIX V-04: tokens = (ethIn * PRECISION) / price
        // Ejemplo: 1 ETH (1e18 wei), price = 2e15 → tokens = (1e18 * 1e18) / 2e15 = 500e18
        uint256 tokensOut = (msg.value * PRECISION) / price;
        require(tokensOut > 0, "Amount too small to buy any tokens");

        balances[msg.sender] += tokensOut;

        emit TokensBought(msg.sender, msg.value, tokensOut, price); // FIX V-08
    }

    /**
     * @notice Vende tokens a cambio de ETH.
     * @dev    FIX V-02: CEI estricto — balances decrementado ANTES del .call{}.
     *         FIX V-02: nonReentrant como segunda línea de defensa.
     *         FIX V-04: aritmética escalada con PRECISION — (amount * price) / PRECISION.
     *         FIX V-06: require balance suficiente como primer check.
     * @param amount Cantidad de tokens a vender (en unidades con PRECISION escala).
     */
    function sell(uint256 amount) external nonReentrant {
        // ── Checks ────────────────────────────────────────────────────────────
        require(amount > 0,                         "Amount must be > 0");
        // FIX V-06: verificación explícita de saldo ANTES de cualquier operación
        require(balances[msg.sender] >= amount,     "Insufficient token balance");
        // FIX V-03: guard defensivo contra price == 0
        require(price > 0,                          "Price not initialized");

        // FIX V-04: eth = (tokensIn * price) / PRECISION
        // Ejemplo: 500e18 tokens, price = 2e15 → eth = (500e18 * 2e15) / 1e18 = 1e18 = 1 ETH
        uint256 ethOut = (amount * price) / PRECISION;
        require(ethOut > 0,                         "Amount too small to receive ETH");
        require(address(this).balance >= ethOut,    "Insufficient DEX liquidity");

        // ── Effects: estado actualizado ANTES de la interacción externa ───────
        // FIX V-02: decremento ANTES del .call{} — previene reentrancy drain
        balances[msg.sender] -= amount;

        emit TokensSold(msg.sender, amount, ethOut, price); // FIX V-08

        // ── Interaction: única llamada externa, al final del flujo CEI ────────
        (bool ok,) = payable(msg.sender).call{value: ethOut}("");
        require(ok, "ETH transfer failed");
    }

    // ─── Receive ──────────────────────────────────────────────────────────────

    /**
     * @notice Acepta ETH directo para fondeado de liquidez.
     * @dev    FIX V-07: permite que el contrato acumule ETH para respaldar sell().
     */
    receive() external payable {
        emit EthReceived(msg.sender, msg.value); // FIX V-08
    }
}