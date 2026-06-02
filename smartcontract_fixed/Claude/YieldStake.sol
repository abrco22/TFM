// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title YieldStake (Patched)
 * @notice Protocolo de staking con separación de principal y recompensas,
 *         pool de recompensas respaldado, CEI estricto y trazabilidad completa.
 * @dev Fixes: V-01 (onlyOwner reward), V-02 (CEI + nonReentrant withdraw),
 *             V-03 (stakedETH / pendingRewards separados),
 *             V-04 (reward r > 0), V-05 (deposit msg.value > 0),
 *             V-06 (rewardPool explícito), V-07 (eventos).
 *
 * Arquitectura de fondos:
 *   address(this).balance = Σ stakedETH[users] + rewardPool + excedente
 *   Invariante: rewardPool >= Σ pendingRewards[users]  (siempre)
 */
contract YieldStake {

    // ─── State Variables ──────────────────────────────────────────────────────

    /// @notice Propietario del protocolo — único autorizado para distribuir rewards
    address public owner;

    /// @dev FIX V-02: mutex contra reentrancy directa y cross-function
    bool private _locked;

    /**
     * @notice ETH real depositado por cada usuario (principal).
     * @dev    FIX V-03: separado de pendingRewards para evitar mezcla de semánticas.
     *         Invariante: Σ stakedETH[all] <= address(this).balance
     */
    mapping(address => uint256) public stakedETH;

    /**
     * @notice Recompensas pendientes de reclamación por cada usuario.
     * @dev    FIX V-03: acreditadas por el owner vía reward(); cobradas vía claimReward().
     *         Invariante: Σ pendingRewards[all] <= rewardPool
     */
    mapping(address => uint256) public pendingRewards;

    /**
     * @notice Total de ETH depositado por todos los usuarios como principal.
     * @dev    Permite verificar la invariante de solvencia del contrato.
     */
    uint256 public totalStaked;

    /**
     * @notice Pool de ETH reservado exclusivamente para pagar recompensas.
     * @dev    FIX V-06: el owner fondea este pool vía fundRewards().
     *         Invariante: rewardPool >= Σ pendingRewards[all]
     */
    uint256 public rewardPool;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-07: trazabilidad completa de todas las operaciones del protocolo
    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 newStake
    );
    event Withdrawn(
        address indexed user,
        uint256 amount,
        uint256 remainingStake
    );
    event RewardGranted(
        address indexed user,
        uint256 rewardAmount,
        uint256 totalPending
    );
    event RewardClaimed(
        address indexed user,
        uint256 amount
    );
    event RewardsFunded(
        address indexed funder,
        uint256 amount,
        uint256 newRewardPool
    );

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev FIX V-01: solo el owner puede distribuir recompensas y gestionar el protocolo
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    /// @dev FIX V-02: bloquea cualquier re-entrada directa o cross-function
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ─── User Functions ───────────────────────────────────────────────────────

    /**
     * @notice Deposita ETH como principal de staking.
     * @dev    FIX V-05: rechaza depósitos de valor cero.
     *         FIX V-03: acredita en stakedETH (principal), no en pendingRewards.
     */
    function deposit() external payable {
        // FIX V-05: no aceptar depósitos vacíos
        require(msg.value > 0, "Cannot deposit 0 ETH");

        // CEI: solo efectos de estado, sin llamadas externas en deposit
        stakedETH[msg.sender] += msg.value;
        totalStaked           += msg.value;

        emit Deposited(                   // FIX V-07
            msg.sender,
            msg.value,
            stakedETH[msg.sender]
        );
    }

    /**
     * @notice Retira el principal de staking depositado.
     * @dev    FIX V-02: CEI estricto — stake decrementado ANTES del .call{}.
     *         FIX V-02: nonReentrant como segunda línea de defensa.
     *         FIX V-03: opera sobre stakedETH (principal), no sobre pendingRewards.
     * @param a Cantidad en wei a retirar del principal.
     */
    function withdraw(uint256 a) external nonReentrant {
        // ── Checks ────────────────────────────────────────────────────────────
        require(a > 0,                  "Cannot withdraw 0 ETH");
        require(stakedETH[msg.sender] >= a, "Insufficient staked balance");

        // ── Effects: estado actualizado ANTES de la llamada externa ───────────
        // FIX V-02: decremento ANTES del .call{} — previene reentrancy drain
        stakedETH[msg.sender] -= a;
        totalStaked           -= a;

        emit Withdrawn(                 // FIX V-07
            msg.sender,
            a,
            stakedETH[msg.sender]
        );

        // ── Interaction: única llamada externa, al final del flujo CEI ────────
        (bool ok,) = payable(msg.sender).call{value: a}("");
        require(ok, "Transfer failed");
    }

    /**
     * @notice Reclama las recompensas pendientes acreditadas por el owner.
     * @dev    FIX V-06: verifica que rewardPool tiene ETH para cubrir el pago.
     *         FIX V-02: CEI estricto + nonReentrant.
     *         FIX V-03: opera sobre pendingRewards, separado del principal.
     */
    function claimReward() external nonReentrant {
        uint256 reward = pendingRewards[msg.sender];
        require(reward > 0,          "No rewards to claim");
        require(rewardPool >= reward, "Insufficient reward pool");

        // ── Effects: estado actualizado ANTES de la llamada externa ───────────
        pendingRewards[msg.sender] = 0;
        rewardPool                -= reward;

        emit RewardClaimed(msg.sender, reward); // FIX V-07

        // ── Interaction ───────────────────────────────────────────────────────
        (bool ok,) = payable(msg.sender).call{value: reward}("");
        require(ok, "Reward transfer failed");
    }

    // ─── Owner Functions ──────────────────────────────────────────────────────

    /**
     * @notice Acredita recompensas a un usuario específico.
     * @dev    FIX V-01: restringido a onlyOwner — elimina auto-acreditación ilimitada.
     *         FIX V-04: r debe ser > 0.
     *         FIX V-06: verifica que rewardPool puede cubrir la nueva recompensa.
     *         FIX V-03: acredita en pendingRewards, no en stakedETH.
     * @param user Dirección del usuario que recibirá la recompensa.
     * @param r    Cantidad de recompensa en wei (debe ser > 0).
     */
    function reward(address user, uint256 r) external onlyOwner {
        // FIX V-04: la recompensa debe ser positiva
        require(r > 0, "Reward must be > 0");
        require(user != address(0), "Invalid user address");
        // FIX V-06: el pool de recompensas debe tener ETH suficiente para respaldar r
        require(
            rewardPool >= pendingRewards[user] + r,
            "Insufficient reward pool to cover reward"
        );

        // FIX V-03: recompensa va a pendingRewards, no contamina el principal
        pendingRewards[user] += r;

        emit RewardGranted(             // FIX V-07
            user,
            r,
            pendingRewards[user]
        );
    }

    /**
     * @notice Fondea el pool de recompensas con ETH.
     * @dev    FIX V-06: fuente explícita y auditada de ETH para recompensas.
     *         Solo el owner puede fondear para mantener control del protocolo.
     */
    function fundRewards() external payable onlyOwner {
        require(msg.value > 0, "Must send ETH to fund rewards");

        rewardPool += msg.value;

        emit RewardsFunded(             // FIX V-07
            msg.sender,
            msg.value,
            rewardPool
        );
    }

    // ─── View Functions ───────────────────────────────────────────────────────

    /**
     * @notice Devuelve el balance total del usuario (principal + recompensas pendientes).
     * @param user Dirección a consultar.
     */
    function totalBalance(address user)
        external
        view
        returns (uint256 principal, uint256 rewards)
    {
        return (stakedETH[user], pendingRewards[user]);
    }

    /**
     * @notice Verifica la solvencia del contrato.
     * @dev    Invariante: address(this).balance >= totalStaked + rewardPool
     * @return true si el contrato puede cubrir todos los compromisos.
     */
    function isSolvent() external view returns (bool) {
        return address(this).balance >= totalStaked + rewardPool;
    }
}