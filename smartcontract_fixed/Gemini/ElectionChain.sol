// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ElectionChain {
    // --- ESTADO ---
    address public immutable admin;
    uint256 public immutable candidates;

    mapping(address => bool) public registered;
    mapping(uint256 => uint256) public votes;

    // --- EVENTOS ---
    event VoterRegistered(address indexed voter);
    event VoteCast(address indexed voter, uint256 indexed candidateId);

    // --- MODIFICADORES ---
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized: Only admin");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor(uint256 _candidates) {
        require(_candidates > 0, "Candidates count must be greater than zero");
        admin = msg.sender;
        candidates = _candidates;
    }

    // --- FUNCIONES ADMINISTRATIVAS ---

    /**
     * @notice Registra o vuelve a habilitar a un votante para la elección.
     * @param user Dirección de la billetera del votante.
     */
    function registerVoter(address user) external onlyAdmin {
        require(user != address(0), "Invalid voter address");
        require(!registered[user], "Voter already registered or eligible");
        
        registered[user] = true;
        emit VoterRegistered(user);
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Permite a un votante registrado emitir su voto por un candidato válido.
     * @param candidateId Identificador numérico del candidato.
     */
    function vote(uint256 candidateId) external {
        // Checks
        require(registered[msg.sender], "Not registered or already voted");
        require(candidateId < candidates, "Invalid candidate");

        // Effects (Patrón Checks-Effects-Interactions: Modificar estado antes de cualquier acción)
        registered[msg.sender] = false;
        votes[candidateId]++;

        emit VoteCast(msg.sender, candidateId);
    }
}