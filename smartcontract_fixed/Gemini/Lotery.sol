// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Lotery {
    // --- ESTADO ---
    address public immutable owner;
    address[] public players;
    
    // Variables para el esquema de aleatoriedad Commit-Reveal
    bytes32 public lotterySecretCommit;
    bool public isCommitSet;
    
    // Variables de ganadores
    address public lotteryWinner;
    uint256 public prizePool;
    mapping(address => uint256) public pendingWithdrawals;

    enum LotteryState { Open, Calculating, Closed }
    LotteryState public currentState;

    // --- EVENTOS ---
    event TicketPurchased(address indexed player, uint256 amount);
    event SecretCommitted(bytes32 commitHash);
    event WinnerSelected(address indexed winner, uint256 prize);
    event PrizeClaimed(address indexed winner, uint256 amount);

    // --- MODIFICADORES ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized: Only owner");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor() {
        owner = msg.sender;
        currentState = LotteryState.Open;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Permite a los usuarios entrar a la lotería comprando un boleto único.
     */
    function enter() external payable {
        require(currentState == LotteryState.Open, "Lottery is not open");
        require(msg.value == 0.01 ether, "Ticket price must be exactly 0.01 ETH");
        
        players.push(msg.sender);
        emit TicketPurchased(msg.sender, msg.value);
    }

    /**
     * @notice Fase 1 del Sorteo: El administrador compromete el hash de un secreto.
     * @param _commitHash Hash keccak256 de una frase o número secreto generado fuera de la cadena.
     */
    function commitSecret(bytes32 _commitHash) external onlyOwner {
        require(players.length > 0, "No players in the lottery");
        require(!isCommitSet, "Secret already committed");
        
        lotterySecretCommit = _commitHash;
        isCommitSet = true;
        currentState = LotteryState.Calculating;

        emit SecretCommitted(_commitHash);
    }

    /**
     * @notice Fase 2 del Sorteo: Revelar el secreto, elegir al ganador y cerrar la ronda de forma segura.
     * @param _revealedSecret El secreto original en texto plano que coincide con el hash guardado.
     */
    function pickWinner(string memory _revealedSecret) external onlyOwner {
        require(isCommitSet, "Commit must be set first");
        require(currentState == LotteryState.Calculating, "Invalid state for selection");
        require(keccak256(abi.encodePacked(_revealedSecret)) == lotterySecretCommit, "Invalid secret reveal");

        // Generación de entropía robusta mezclando el secreto revelado con factores del bloque
        uint256 randomness = uint256(
            keccak256(
                abi.encodePacked(
                    _revealedSecret,
                    block.timestamp,
                    block.prevrandao, // Reemplazo moderno y nativo de EVM para block.difficulty
                    players.length
                )
            )
        );

        uint256 winnerIndex = randomness % players.length;
        lotteryWinner = players[winnerIndex];
        
        uint256 totalPrize = address(this).balance;
        pendingWithdrawals[lotteryWinner] += totalPrize;

        emit WinnerSelected(lotteryWinner, totalPrize);

        // Limpieza de estado completa antes de reabrir
        delete players;
        isCommitSet = false;
        lotterySecretCommit = bytes32(0);
        currentState = LotteryState.Open;
    }

    /**
     * @notice Aplica el patrón Pull Payment para que el ganador retire sus ganancias de forma segura.
     */
    function claimPrize() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No prizes to claim");

        // Checks-Effects-Interactions
        pendingWithdrawals[msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Withdrawal transfer failed");

        emit PrizeClaimed(msg.sender, amount);
    }
}
