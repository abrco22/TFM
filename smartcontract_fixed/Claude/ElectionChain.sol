// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ElectionChain (Patched)
 * @notice Sistema de votación on-chain con control de acceso, anti-double-voting
 *         robusto, ciclo de vida de elección y trazabilidad completa.
 * @dev Fixes: V-01 (onlyAdmin), V-02 (reRegister rediseñado), V-03 (zero-address),
 *             V-04 (votingOpen lifecycle), V-05 (constructor guard), V-06 (eventos).
 */
contract ElectionChain {

    // ─── State Variables ──────────────────────────────────────────────────────

    /// @notice Dirección de la autoridad electoral (único actor privilegiado)
    address public admin;

    /// @notice Indica si el período de votación está activo
    bool public votingOpen;

    /// @notice Número total de candidatos válidos
    uint256 public candidates;

    /// @dev true = el usuario está registrado y aún no ha votado
    mapping(address => bool) public registered;

    /// @dev Conteo de votos por candidato (candidateId => voteCount)
    mapping(uint256 => uint256) public votes;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-06: eventos para auditoría y trazabilidad on-chain
    event VoterRegistered(address indexed user);
    event VoterRegistrationCorrected(address indexed user);
    event Voted(address indexed voter, uint256 indexed candidateId);
    event VotingStatusChanged(bool isOpen);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev FIX V-01: solo la autoridad electoral puede ejecutar funciones privilegiadas
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param _candidates Número de candidatos (debe ser > 0)
     */
    constructor(uint256 _candidates) {
        // FIX V-05: previene despliegue de contrato con 0 candidatos
        require(_candidates > 0, "Must have at least one candidate");

        admin      = msg.sender;
        candidates = _candidates;
        // La votación comienza cerrada; el admin la abre explícitamente
        votingOpen = false;
    }

    // ─── Admin Functions ──────────────────────────────────────────────────────

    /**
     * @notice Registra un votante legítimo.
     * @dev    FIX V-01: restringido a onlyAdmin.
     *         FIX V-03: valida que user != address(0).
     * @param user Dirección del votante a registrar.
     */
    function registerVoter(address user) external onlyAdmin {
        // FIX V-03: zero-address check
        require(user != address(0), "Invalid address");
        require(!registered[user], "Already registered");

        registered[user] = true;

        emit VoterRegistered(user); // FIX V-06
    }

    /**
     * @notice Corrige el registro de un votante (uso excepcional y auditado).
     * @dev    FIX V-02: reemplaza la función `reRegister()` irrestricta.
     *         Solo el admin puede re-habilitar un registro, dejando traza on-chain.
     *         FIX V-01: restringido a onlyAdmin.
     *         FIX V-03: valida que user != address(0).
     * @param user Dirección del votante cuyo registro se corrige.
     */
    function correctRegistration(address user) external onlyAdmin {
        // FIX V-03: zero-address check
        require(user != address(0), "Invalid address");

        registered[user] = true;

        emit VoterRegistrationCorrected(user); // FIX V-06 — evento diferenciado para auditoría
    }

    /**
     * @notice Abre el período de votación.
     * @dev    FIX V-04: control de ciclo de vida de la elección.
     */
    function openVoting() external onlyAdmin {
        require(!votingOpen, "Already open");
        votingOpen = true;
        emit VotingStatusChanged(true); // FIX V-06
    }

    /**
     * @notice Cierra el período de votación.
     * @dev    FIX V-04: control de ciclo de vida de la elección.
     */
    function closeVoting() external onlyAdmin {
        require(votingOpen, "Already closed");
        votingOpen = false;
        emit VotingStatusChanged(false); // FIX V-06
    }

    // ─── Voter Functions ──────────────────────────────────────────────────────

    /**
     * @notice Emite un voto por un candidato.
     * @dev    El mecanismo anti-double-voting (registered = false) sigue intacto.
     *         FIX V-04: requiere que la votación esté abierta.
     * @param candidateId Índice del candidato (0-indexed, debe ser < candidates).
     */
    function vote(uint256 candidateId) external {
        // FIX V-04: la votación debe estar activa
        require(votingOpen, "Voting is not open");
        require(registered[msg.sender], "Not registered");
        require(candidateId < candidates, "Invalid candidate");

        // CEI: efecto de estado antes de cualquier lógica posterior
        registered[msg.sender] = false;
        votes[candidateId]++;

        emit Voted(msg.sender, candidateId); // FIX V-06
    }
}