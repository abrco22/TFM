// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title VaultBank (Patched)
 * @notice Banco de custodia de ETH con CEI estricto, protección contra
 *         reentrancy, contabilidad íntegra de excedentes y trazabilidad completa.
 * @dev Fixes: V-01 (CEI + nonReentrant), V-02+V-03 (totalDeposited + adminWithdraw),
 *             V-04 (deposit guard), V-05 (eventos).
 */
contract VaultBank {

    // ─── State Variables ──────────────────────────────────────────────────────

    /// @notice Propietario del contrato
    address public owner;

    /// @notice Balance individual de cada depositante
    mapping(address => uint256) public balances;

    /**
     * @notice Suma total de ETH comprometido con depositantes.
     * @dev    FIX V-02+V-03: invariante contable que separa fondos de usuarios
     *         del excedente disponible para adminWithdraw().
     *         Invariante: totalDeposited <= address(this).balance (siempre).
     */
    uint256 public totalDeposited;

    /// @dev FIX V-01: mutex contra reentrancy directa y cross-function
    bool private _locked;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-05: trazabilidad completa de todas las operaciones del vault
    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 newBalance
    );
    event Withdrawn(
        address indexed user,
        uint256 amount,
        uint256 remainingBalance
    );
    event AdminWithdrawn(address indexed admin, uint256 amount);
    event EthReceived(address indexed sender, uint256 amount);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev FIX V-01: bloquea cualquier re-entrada directa o cross-function
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
     * @notice Deposita ETH acreditándolo al balance del caller.
     * @dev    FIX V-04: rechaza depósitos de 0 ETH.
     *         FIX V-02: incrementa totalDeposited para mantener invariante contable.
     */
    function deposit() external payable {
        // FIX V-04: no aceptar depósitos de valor cero
        require(msg.value > 0, "Cannot deposit 0 ETH");

        // CEI: solo efectos de estado, sin llamadas externas
        balances[msg.sender] += msg.value;
        totalDeposited       += msg.value; // FIX V-03

        emit Deposited(                    // FIX V-05
            msg.sender,
            msg.value,
            balances[msg.sender]
        );
    }

    /**
     * @notice Retira ETH previamente depositado.
     * @dev    FIX V-01: patrón CEI estricto — balance decrementado ANTES del .call{}.
     *         FIX V-01: nonReentrant como segunda línea de defensa.
     *         FIX V-03: decrementa totalDeposited al retirar.
     * @param amount Cantidad en wei a retirar.
     */
    function withdraw(uint256 amount) external nonReentrant {
        // ── Checks ────────────────────────────────────────────────────────────
        require(amount > 0,                     "Cannot withdraw 0 ETH");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // ── Effects: ANTES de cualquier llamada externa (FIX V-01) ───────────
        balances[msg.sender] -= amount;
        totalDeposited       -= amount; // FIX V-03: mantener invariante contable

        emit Withdrawn(                 // FIX V-05
            msg.sender,
            amount,
            balances[msg.sender]
        );

        // ── Interaction: única llamada externa, al final del flujo ────────────
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    // ─── Owner Functions ──────────────────────────────────────────────────────

    /**
     * @notice Retira el ETH excedente (no comprometido con usuarios) al owner.
     * @dev    FIX V-03: único mecanismo para rescatar ETH recibido por receive().
     *         El excedente = address(this).balance - totalDeposited.
     *         Los fondos de usuarios son matemáticamente intocables.
     *         Patrón CEI: emit antes del .call{} externo.
     */
    function adminWithdraw() external nonReentrant {
        require(msg.sender == owner, "Not authorized");

        // FIX V-03: solo puede retirar ETH no comprometido con depositantes
        uint256 excess = address(this).balance - totalDeposited;
        require(excess > 0, "No excess funds to withdraw");

        // CEI: emit antes del call externo
        emit AdminWithdrawn(owner, excess); // FIX V-05

        (bool ok,) = payable(owner).call{value: excess}("");
        require(ok, "Admin transfer failed");
    }

    // ─── Receive ──────────────────────────────────────────────────────────────

    /**
     * @notice Acepta ETH directo sin acreditarlo en balances de usuarios.
     * @dev    FIX V-02: solo emite evento — no modifica balances ni totalDeposited.
     *         El ETH recibido aquí es excedente retirable por adminWithdraw().
     *         Los depósitos voluntarios deben usar deposit() explícitamente.
     */
    receive() external payable {
        // FIX V-02+V-05: trazabilidad sin modificar contabilidad de usuarios
        emit EthReceived(msg.sender, msg.value);
    }
}