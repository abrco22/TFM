// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SafeVault (Patched)
 * @notice Vault de custodia de ETH con acceso restringido, retiro individual
 *         para depositantes, contabilidad íntegra y protección contra reentrancy.
 * @dev Fixes: V-01 (onlyOwner en adminWithdraw), V-02 (CEI + nonReentrant),
 *             V-03 (withdraw para usuarios), V-04 (totalDeposited invariant),
 *             V-05 (receive evento), V-06 (eventos completos).
 */
contract SafeVault {

    // ─── State Variables ──────────────────────────────────────────────────────

    /// @notice Propietario del vault — único autorizado para adminWithdraw()
    /// @dev    FIX V-01: reemplaza la ausencia total de access control
    address public owner;

    /// @dev FIX V-02: mutex contra reentrancy directa y cross-function
    bool private _locked;

    /// @notice Balance individual de cada depositante
    mapping(address => uint256) public deposits;

    /**
     * @notice Suma total de ETH comprometido con depositantes.
     * @dev    FIX V-04: invariante contable que protege fondos de usuarios
     *         frente a adminWithdraw(). Invariante: totalDeposited <= address(this).balance
     */
    uint256 public totalDeposited;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-06: trazabilidad completa de todas las operaciones del vault
    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed user, uint256 amount, uint256 remainingBalance);
    event AdminWithdrawn(address indexed admin, uint256 amount);
    event EthReceived(address indexed sender, uint256 amount);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev FIX V-02: bloquea cualquier re-entrada directa o cross-function
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() {
        // FIX V-01: asignar owner en deploy para access control en adminWithdraw()
        owner = msg.sender;
    }

    // ─── User Functions ───────────────────────────────────────────────────────

    /**
     * @notice Deposita ETH en el vault acreditándolo al caller.
     * @dev    FIX V-04: incrementa totalDeposited para mantener invariante contable.
     *         FIX V-06: emite Deposited para trazabilidad.
     */
    function deposit() external payable {
        require(msg.value > 0, "Cannot deposit 0 ETH");

        // CEI: efectos de estado antes de cualquier interacción
        deposits[msg.sender] += msg.value;
        totalDeposited       += msg.value;  // FIX V-04

        emit Deposited(                     // FIX V-06
            msg.sender,
            msg.value,
            deposits[msg.sender]
        );
    }

    /**
     * @notice Retira ETH previamente depositado por el caller.
     * @dev    FIX V-03: función de retiro para usuarios — ausente en el original.
     *         Patrón CEI estricto: estado actualizado ANTES de la llamada externa.
     *         FIX V-02: nonReentrant previene reentrancy directa y cross-function.
     *         FIX V-04: decrementa totalDeposited al retirar.
     * @param amount Cantidad en wei a retirar (debe ser <= deposits[msg.sender]).
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0,                      "Cannot withdraw 0 ETH");
        require(deposits[msg.sender] >= amount,  "Insufficient balance");

        // ── CEI: efectos ANTES de la interacción externa ───────────────────────
        deposits[msg.sender] -= amount;
        totalDeposited       -= amount;  // FIX V-04

        emit Withdrawn(                  // FIX V-06
            msg.sender,
            amount,
            deposits[msg.sender]
        );

        // ── Interacción: transferencia al final del flujo ──────────────────────
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");
    }

    // ─── Admin Functions ──────────────────────────────────────────────────────

    /**
     * @notice Retira el ETH excedente (no comprometido con usuarios) al owner.
     * @dev    FIX V-01: restringido exclusivamente al owner.
     *         FIX V-02: nonReentrant + CEI (emit antes del call).
     *         FIX V-04: solo puede retirar balance - totalDeposited (fondos libres).
     *                   Garantiza que los depósitos de usuarios son intocables.
     */
    function adminWithdraw() external nonReentrant {
        // FIX V-01: solo el owner puede ejecutar esta función
        require(msg.sender == owner, "Not authorized");

        // FIX V-04: el owner solo puede retirar ETH no comprometido con usuarios
        uint256 available = address(this).balance - totalDeposited;
        require(available > 0, "No excess funds to withdraw");

        // ── CEI: emit antes del call externo ──────────────────────────────────
        emit AdminWithdrawn(owner, available); // FIX V-06

        // ── Interacción: transferencia al final ───────────────────────────────
        (bool ok,) = payable(owner).call{value: available}("");
        require(ok, "Admin transfer failed");
    }

    // ─── Receive ──────────────────────────────────────────────────────────────

    /**
     * @notice Acepta ETH directo sin acreditarlo en deposits[].
     * @dev    FIX V-05: emite evento para trazabilidad; no modifica totalDeposited.
     *         El ETH recibido aquí incrementa el excedente disponible para adminWithdraw().
     *         Los remitentes que quieran acreditar balance deben usar deposit().
     */
    receive() external payable {
        // FIX V-05: registro on-chain sin modificar la contabilidad de usuarios
        emit EthReceived(msg.sender, msg.value); // FIX V-06
    }
}