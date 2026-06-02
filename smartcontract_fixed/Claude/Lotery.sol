// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Lotery (Patched)
 * @notice Lotería on-chain con aleatoriedad commit-reveal, access control,
 *         entrada única por jugador, mínimo de participantes y pull payment.
 * @dev Fixes: V-01 (commit-reveal RNG), V-02 (onlyOwner pick),
 *             V-03 (CEI strict), V-04 (MIN_PLAYERS), V-05 (hasEntered),
 *             V-06 (pull payment), V-07 (eventos).
 */
contract Lotery {

    // ─── Constants ────────────────────────────────────────────────────────────

    /// @notice Precio fijo de entrada por jugador
    uint256 public constant ENTRY_PRICE = 0.01 ether;

    /**
     * @notice Mínimo de jugadores para ejecutar el sorteo.
     * @dev    FIX V-04: impide que un único participante gane trivialmente.
     */
    uint256 public constant MIN_PLAYERS = 2;

    // ─── State Variables ──────────────────────────────────────────────────────

    /// @notice Propietario del contrato (único que puede sortear)
    address public owner;

    /// @notice Lista de participantes de la ronda actual
    address[] public players;

    /// @dev FIX V-05: control de entrada única por dirección
    mapping(address => bool) public hasEntered;

    // ── Commit-Reveal RNG State (FIX V-01) ────────────────────────────────────

    /// @notice Hash del secreto commiteado por el owner antes del sorteo
    bytes32 public entropyCommitment;

    /// @notice Número de bloque en que se realizó el commit (para blockhash)
    uint256 public commitBlock;

    /// @notice true si hay un commit pendiente de reveal
    bool public commitPending;

    // ── Pull Payment State (FIX V-06) ─────────────────────────────────────────

    /// @notice Premio pendiente de reclamación por el ganador
    address public pendingWinner;

    /// @notice Importe pendiente de reclamación
    uint256 public pendingPrize;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-07: trazabilidad completa
    event PlayerEntered(address indexed player, uint256 totalPlayers);
    event EntropyCommitted(address indexed owner, uint256 atBlock);
    event WinnerSelected(address indexed winner, uint256 prize, uint256 round);
    event PrizeClaimed(address indexed winner, uint256 amount);

    // ─── Round Counter ────────────────────────────────────────────────────────

    uint256 public round;

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev FIX V-02: solo el owner puede ejecutar funciones privilegiadas
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
        round = 1;
    }

    // ─── Player Functions ─────────────────────────────────────────────────────

    /**
     * @notice Registra al remitente como participante de la ronda actual.
     * @dev    FIX V-05: una dirección solo puede entrar una vez por ronda.
     *         FIX V-07: emite PlayerEntered.
     */
    function enter() external payable {
        require(msg.value == ENTRY_PRICE, "Must send exactly 0.01 ETH");
        // FIX V-05: previene entradas múltiples desde la misma dirección
        require(!hasEntered[msg.sender], "Already entered this round");
        // No se puede entrar una vez iniciada la fase de reveal
        require(!commitPending, "Draw in progress, wait for next round");

        hasEntered[msg.sender] = true;
        players.push(msg.sender);

        emit PlayerEntered(msg.sender, players.length); // FIX V-07
    }

    /**
     * @notice Reclamar el premio si el remitente es el ganador pendiente.
     * @dev    FIX V-06: patrón pull payment — desacopla sorteo de transferencia.
     *         Patrón CEI: estado limpiado antes del call externo.
     */
    function claimPrize() external {
        require(msg.sender == pendingWinner, "Not the winner");
        require(pendingPrize > 0, "No prize to claim");

        // CEI: estado limpiado ANTES de la transferencia (FIX V-03 aplicado aquí)
        uint256 amount  = pendingPrize;
        pendingWinner   = address(0);
        pendingPrize    = 0;

        emit PrizeClaimed(msg.sender, amount); // FIX V-07

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");
    }

    // ─── Owner Functions ──────────────────────────────────────────────────────

    /**
     * @notice Fase 1 del sorteo: el owner commitea un secreto hasheado.
     * @dev    FIX V-01: commit-reveal — el owner no conoce blockhash futuro
     *         en el momento del commit, eliminando la predictibilidad del RNG.
     * @param _commitment keccak256(abi.encodePacked(secret, address(this)))
     *                    El salt con address(this) previene reutilización cross-contract.
     */
    function commitEntropy(bytes32 _commitment) external onlyOwner {
        // FIX V-04: mínimo de jugadores antes de iniciar el sorteo
        require(players.length >= MIN_PLAYERS, "Not enough players");
        require(!commitPending, "Commit already pending");
        require(_commitment != bytes32(0), "Invalid commitment");

        entropyCommitment = _commitment;
        commitBlock       = block.number;
        commitPending     = true;

        emit EntropyCommitted(msg.sender, block.number); // FIX V-07
    }

    /**
     * @notice Fase 2 del sorteo: el owner revela el secreto y se determina el ganador.
     * @dev    FIX V-01: la aleatoriedad combina el secreto del owner (desconocido
     *         para jugadores) con blockhash(commitBlock+1) (desconocido para el owner
     *         en el momento del commit). Ninguna parte puede manipular ambas fuentes.
     *         FIX V-02: restringido a onlyOwner.
     *         FIX V-03: CEI — todo el estado se resetea ANTES del pull payment setup.
     * @param secret El valor original commiteado: keccak256(secret, address(this)) == commitment.
     */
    function pick(bytes32 secret) external onlyOwner {
        require(commitPending, "No commit pending");
        // FIX V-01: verificar que el secreto corresponde al commitment
        require(
            keccak256(abi.encodePacked(secret, address(this))) == entropyCommitment,
            "Secret mismatch"
        );
        // El blockhash solo está disponible para los últimos 256 bloques
        require(block.number > commitBlock, "Wait one block after commit");
        require(block.number <= commitBlock + 255, "Commitment expired, recommit");

        // ── FIX V-03: CEI — capturar estado ANTES de modificarlo ──────────────

        address[] memory currentPlayers = players;
        uint256   prize                 = address(this).balance;
        uint256   currentRound          = round;

        // Resetear estado de la ronda ANTES de cualquier interacción externa
        // FIX V-05: limpiar hasEntered para cada jugador de la ronda
        for (uint256 i = 0; i < currentPlayers.length; i++) {
            hasEntered[currentPlayers[i]] = false;
        }
        delete players;

        commitPending     = false;
        entropyCommitment = bytes32(0);
        commitBlock       = 0;
        round++;

        // ── FIX V-01: RNG commit-reveal ───────────────────────────────────────
        // blockhash(commitBlock) es conocido ahora pero era desconocido al commitear
        uint256 randomness = uint256(
            keccak256(
                abi.encodePacked(
                    secret,
                    blockhash(commitBlock),
                    currentPlayers.length
                )
            )
        );
        address winner = currentPlayers[randomness % currentPlayers.length];

        // FIX V-06: pull payment — registrar premio en lugar de transferir directamente
        pendingWinner = winner;
        pendingPrize  = prize;

        emit WinnerSelected(winner, prize, currentRound); // FIX V-07
    }
}