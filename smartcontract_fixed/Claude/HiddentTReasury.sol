// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HiddenTreasury (Patched)
 * @notice Contrato de custodia de ETH con contabilidad íntegra, protección
 *         contra reentrancy, control de ownership seguro y trazabilidad completa.
 * @dev Fixes: V-01 (nonReentrant), V-02+V-05 (totalDeposited invariant),
 *             V-03 (zero-address owner), V-04 (receive sin acreditación),
 *             V-06 (eventos completos).
 */
contract HiddenTreasury {

    // ─── State Variables ──────────────────────────────────────────────────────

    address public owner;

    /// @dev FIX V-01: mutex para protección contra reentrancy
    bool private _locked;

    /// @notice Balances individuales de cada depositante
    mapping(address => uint256) public balances;

    /**
     * @notice Total de ETH comprometido con usuarios (suma de todos los balances).
     * @dev    FIX V-02 + V-05: invariante contable que impide al owner drenar
     *         fondos de usuarios a través de transferToTreasury().
     */
    uint256 public totalDeposited;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-06: trazabilidad completa de todas las operaciones críticas
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event TreasuryTransfer(address indexed target, uint256 amount);
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event EthReceived(address indexed sender, uint256 amount);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev FIX V-01: bloquea cualquier re-entrada (directa o cross-function)
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
     * @notice Deposita ETH y acredita el balance del remitente.
     * @dev    FIX V-02: incrementa totalDeposited para mantener invariante contable.
     */
    function deposit() external payable {
        require(msg.value > 0, "No ETH sent");

        // CEI: efectos de estado antes de cualquier interacción externa
        balances[msg.sender] += msg.value;
        totalDeposited      += msg.value; // FIX V-02

        emit Deposited(msg.sender, msg.value); // FIX V-06
    }

    /**
     * @notice Retira ETH previamente depositado.
     * @dev    Patrón CEI aplicado correctamente.
     *         FIX V-01: nonReentrant bloquea reentrancy directa y cross-function.
     *         FIX V-02: decrementa totalDeposited al retirar.
     * @param amount Cantidad en wei a retirar.
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // CEI: efectos ANTES de la interacción externa
        balances[msg.sender] -= amount;
        totalDeposited       -= amount; // FIX V-02

        emit Withdrawn(msg.sender, amount); // FIX V-06

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");
    }

    // ─── Owner Functions ──────────────────────────────────────────────────────

    /**
     * @notice Transfiere ETH "libre" (no comprometido con usuarios) al target.
     * @dev    FIX V-02 + V-05: la invariante totalDeposited garantiza que el owner
     *         solo puede mover ETH que no pertenece a ningún depositante.
     *         FIX V-03: validación de zero-address en target.
     * @param target  Destinatario de los fondos (no puede ser address(0)).
     * @param amount  Cantidad en wei a transferir.
     */
    function transferToTreasury(address target, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        require(target != address(0), "Invalid target");   // FIX V-03
        require(amount > 0, "Zero amount");

        // FIX V-02 + V-05: el ETH disponible para el owner es solo el excedente
        // sobre los fondos comprometidos con usuarios
        require(
            address(this).balance - amount >= totalDeposited,
            "Cannot withdraw user funds"
        );

        emit TreasuryTransfer(target, amount); // FIX V-06

        (bool ok,) = payable(target).call{value: amount}("");
        require(ok, "Transfer failed");
    }

    /**
     * @notice Transfiere la propiedad del contrato a una nueva dirección.
     * @dev    FIX V-03: zero-address check obligatorio.
     * @param newOwner Nueva dirección del owner (no puede ser address(0)).
     */
    function changeOwner(address newOwner) external {
        require(msg.sender == owner, "Only owner");
        // FIX V-03: previene pérdida irrecuperable de ownership
        require(newOwner != address(0), "Invalid owner address");

        emit OwnerChanged(owner, newOwner); // FIX V-06

        owner = newOwner;
    }

    // ─── Receive ──────────────────────────────────────────────────────────────

    /**
     * @notice Acepta ETH enviado directamente sin acreditar balances.
     * @dev    FIX V-04: elimina la acreditación automática en receive().
     *         Los depósitos voluntarios deben usar deposit() explícitamente.
     *         El ETH recibido aquí queda como excedente libre para el owner.
     */
    receive() external payable {
        // FIX V-04: solo registro del evento, sin modificar balances de usuarios
        emit EthReceived(msg.sender, msg.value); // FIX V-06
    }
}