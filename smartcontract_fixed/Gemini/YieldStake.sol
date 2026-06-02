// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract YieldStake {
    // --- ESTADO ---
    address public immutable distributor;
    mapping(address => uint256) public stake;
    
    // Estado para ReentrancyGuard básico interno
    uint8 private unlocked = 1;

    // --- EVENTOS ---
    event Deposited(address indexed user, uint256 amount);
    event RewardAdded(address indexed user, uint256 rewardAmount);
    event Withdrawn(address indexed user, uint256 amount);

    // --- MODIFICADORES ---
    modifier onlyDistributor() {
        require(msg.sender == distributor, "Not authorized: Only distributor");
        _;
    }

    modifier nonReentrant() {
        require(unlocked == 1, "ReentrancyGuard: reentrant call");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // --- CONSTRUCTOR ---
    constructor() {
        distributor = msg.sender;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Permite a los usuarios depositar Ether para hacer staking.
     */
    function deposit() external payable {
        require(msg.value > 0, "Cannot deposit 0 ETH");
        stake[msg.sender] += msg.value;
        
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Asigna de forma segura una recompensa a un usuario específico.
     * @dev Restringido únicamente al distribuidor autorizado del protocolo.
     * @param user Dirección del usuario acreedor de la recompensa.
     * @param r Cantidad de recompensa en wei.
     */
    function reward(address user, uint256 r) external onlyDistributor {
        require(user != address(0), "Invalid user address");
        require(r > 0, "Reward must be greater than zero");
        
        stake[user] += r;
        
        emit RewardAdded(user, r);
    }

    /**
     * @notice Permite retirar el Ether del staking junto con sus recompensas.
     * @param a Cantidad de wei a retirar.
     */
    function withdraw(uint256 a) external nonReentrant {
        require(a > 0, "Amount must be greater than zero");
        require(stake[msg.sender] >= a, "Insufficient staking balance");

        // Checks-Effects-Interactions (Efecto aplicado antes de la llamada externa)
        stake[msg.sender] -= a;

        (bool ok, ) = payable(msg.sender).call{value: a}("");
        require(ok, "ETH transfer failed");

        emit Withdrawn(msg.sender, a);
    }
}
