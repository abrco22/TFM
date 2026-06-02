// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SimpleAuction (Patched)
 * @notice Subasta con pull payment para pujadores y seller, deadline temporal,
 *         protección contra reentrancy y trazabilidad completa.
 * @dev Fixes: V-01+V-05 (pendingReturns pull payment), V-02 (seller pull payment),
 *             V-03+V-04 (CEI + nonReentrant en withdraw), V-06 (no-bid guard),
 *             V-07 (auctionEnd deadline), V-08 (receive evento), V-09 (eventos).
 */
contract SimpleAuction {

    // ─── State Variables ──────────────────────────────────────────────────────

    /// @notice Vendedor que desplegó el contrato y recibirá el pago
    address public seller;

    /// @notice Timestamp UNIX en que la subasta cierra automáticamente
    /// @dev    FIX V-07: deadline fijo fijado en el constructor
    uint256 public auctionEnd;

    /// @notice Puja más alta actual en wei
    uint256 public highestBid;

    /// @notice Dirección del pujador con la oferta más alta
    address public highestBidder;

    /// @notice true si la subasta ha sido cerrada oficialmente
    bool public ended;

    /**
     * @notice Fondos pendientes de retirar por cada participante.
     * @dev    FIX V-01+V-05: pull payment — pujadores desplazados acumulan aquí
     *         su reembolso en lugar de recibirlo por push durante bid().
     *         FIX V-02: el seller acumula aquí el highestBid al cerrar.
     */
    mapping(address => uint256) public pendingReturns;

    /// @dev FIX V-03: mutex contra reentrancy en withdraw()
    bool private _locked;

    // ─── Events ───────────────────────────────────────────────────────────────

    event NewBid(address indexed bidder, uint256 amount);
    // FIX V-09: eventos críticos ausentes en el original
    event AuctionEnded(address indexed winner, uint256 amount);
    event BidWithdrawn(address indexed bidder, uint256 amount);
    event EthReceived(address indexed sender, uint256 amount);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev FIX V-03: bloquea reentrancy directa y cross-function en withdraw()
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param _duration Duración de la subasta en segundos desde el deploy.
     */
    constructor(uint256 _duration) {
        require(_duration > 0, "Duration must be > 0");

        seller     = msg.sender;
        // FIX V-07: deadline inmutable fijado en deploy
        auctionEnd = block.timestamp + _duration;
    }

    // ─── Bidding Functions ────────────────────────────────────────────────────

    /**
     * @notice Registra una nueva puja si supera la actual y la subasta está activa.
     * @dev    FIX V-01+V-05: acumula el reembolso del pujador desplazado en
     *         pendingReturns en lugar de enviarlo por push (previene DoS y pérdida).
     *         FIX V-07: verifica que no ha expirado el deadline.
     */
    function bid() external payable {
        // FIX V-07: la subasta debe estar dentro del período activo
        require(block.timestamp < auctionEnd, "Auction has expired");
        require(!ended,          "Auction already ended");
        require(msg.value > highestBid, "Bid too low");

        // ── CEI: efectos de estado ANTES de cualquier lógica de transferencia ──

        // FIX V-01+V-05: acumular reembolso del pujador anterior en pull payment
        // No se hace ninguna llamada externa aquí — cero riesgo de reentrancy
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBid    = msg.value;
        highestBidder = msg.sender;

        emit NewBid(msg.sender, msg.value);
    }

    // ─── Withdrawal Functions ─────────────────────────────────────────────────

    /**
     * @notice Retira los fondos pendientes del caller (pujadores desplazados o seller).
     * @dev    FIX V-01: pull payment — cada participante retira sus fondos
     *         en lugar de recibirlos por push.
     *         FIX V-03+V-04: CEI estricto + nonReentrant eliminan reentrancy
     *         y DoS por destinatario malicioso.
     */
    function withdraw() external nonReentrant {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        // ── CEI: estado a 0 ANTES de la llamada externa ───────────────────────
        pendingReturns[msg.sender] = 0;

        emit BidWithdrawn(msg.sender, amount); // FIX V-09

        // ── Interacción: única llamada externa del contrato ───────────────────
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Withdrawal failed");
    }

    // ─── Auction Lifecycle ────────────────────────────────────────────────────

    /**
     * @notice Cierra la subasta, acredita el pago al seller y registra el ganador.
     * @dev    FIX V-02: seller cobra via pull payment (pendingReturns) — no push.
     *         FIX V-03: sin .call{} aquí; CEI trivialmente satisfecho.
     *         FIX V-04: al no haber push payment, no hay DoS posible.
     *         FIX V-06: require(highestBidder != address(0)) — no subasta vacía.
     *         FIX V-07: puede cerrarse manualmente después del deadline
     *                   O llamarse por el seller después del deadline.
     */
    function endAuction() external {
        require(msg.sender == seller, "Only seller");
        // FIX V-07: el seller solo puede cerrar después del deadline
        require(block.timestamp >= auctionEnd, "Auction still active");
        require(!ended, "Already ended");
        // FIX V-06: no cerrar subasta sin pujas (highestBidder sería address(0))
        require(highestBidder != address(0), "No bids placed");

        // ── CEI: todos los efectos de estado antes de cualquier interacción ───

        ended = true;

        // FIX V-02: pull payment al seller — acreditar en lugar de transferir
        // El seller retira vía withdraw() cuando lo desee
        pendingReturns[seller] += highestBid;

        emit AuctionEnded(highestBidder, highestBid); // FIX V-09

        // No hay ninguna llamada externa aquí — cero riesgo de reentrancy o DoS
    }

    // ─── Receive ──────────────────────────────────────────────────────────────

    /**
     * @notice Acepta ETH directo para financiación inicial o donaciones.
     * @dev    FIX V-08: emite evento para trazabilidad del ETH externo.
     */
    receive() external payable {
        emit EthReceived(msg.sender, msg.value); // FIX V-09
    }
}