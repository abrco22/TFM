// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Crowdfunding (Patched)
 * @notice Contrato de crowdfunding con protecciones contra reentrancy,
 *         validación de goal/deadline y separación de flujos owner/contributor.
 * @dev Fixes aplicados: V-01 (CEI pattern), V-02 (goal guard),
 *      V-03 (contribute guards), V-04 (constructor guards), V-05 (eventos).
 */
contract Crowdfunding {

    // ─── State Variables ──────────────────────────────────────────────────────

    address public owner;
    uint256 public goal;
    uint256 public deadline;
    mapping(address => uint256) public contributions;

    // FIX V-01: mutex de reentrancy guard manual (sin dependencias externas)
    bool private _locked;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-05: eventos para trazabilidad on-chain
    event Contributed(address indexed contributor, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event Withdrawn(address indexed owner, uint256 amount);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev Protección contra reentrancy (FIX V-01)
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    /// @param _goal  Objetivo de recaudación en wei (debe ser > 0)
    /// @param _time  Duración en segundos hasta el deadline (debe ser > 0)
    constructor(uint256 _goal, uint256 _time) {
        // FIX V-04: validación de parámetros de construcción
        require(_goal > 0, "Goal must be > 0");
        require(_time > 0, "Duration must be > 0");

        owner    = msg.sender;
        goal     = _goal;
        deadline = block.timestamp + _time;
    }

    // ─── External Functions ───────────────────────────────────────────────────

    /**
     * @notice Registra una contribución al crowdfunding.
     * @dev    FIX V-03: rechaza contribuciones después del deadline o de valor cero.
     */
    function contribute() external payable {
        // FIX V-03: el plazo debe estar vigente
        require(block.timestamp <= deadline, "Campaign ended");
        // FIX V-03: no aceptar contribuciones de valor cero
        require(msg.value > 0, "Zero contribution");

        contributions[msg.sender] += msg.value;

        emit Contributed(msg.sender, msg.value); // FIX V-05
    }

    /**
     * @notice El owner retira los fondos si el goal fue alcanzado al cierre.
     * @dev    FIX V-02: solo ejecutable post-deadline Y si balance >= goal.
     *         FIX V-01: patrón CEI + nonReentrant.
     */
    function withdrawAll() external nonReentrant {
        require(msg.sender == owner, "Not owner");

        // FIX V-02: el plazo debe haber vencido
        require(block.timestamp > deadline, "Campaign active");
        // FIX V-02: el goal debe haberse alcanzado
        uint256 balance = address(this).balance;
        require(balance >= goal, "Goal not reached");

        // FIX V-01: CEI — efecto de estado antes de la interacción externa
        // (el balance del contrato es la única variable de estado relevante aquí;
        //  la transferencia completa vacía el contrato de forma atómica)
        emit Withdrawn(owner, balance); // FIX V-05

        (bool ok,) = payable(owner).call{value: balance}("");
        require(ok, "Transfer failed");
    }

    /**
     * @notice Reembolsa al contribuyente si el goal NO fue alcanzado al cierre.
     * @dev    FIX V-01: estado reseteado ANTES de la llamada externa (CEI).
     *         FIX V-02: solo ejecutable si el goal no fue alcanzado.
     */
    function refund() external nonReentrant {
        // FIX V-02: el plazo debe haber vencido
        require(block.timestamp > deadline, "Campaign active");
        // FIX V-02: el goal NO debe haberse alcanzado (flujo excluyente con withdrawAll)
        require(address(this).balance < goal, "Goal was reached, no refunds");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "Nothing to refund");

        // FIX V-01: CEI — efecto ANTES de la interacción (previene reentrancy)
        contributions[msg.sender] = 0;

        emit Refunded(msg.sender, amount); // FIX V-05

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Transfer failed");
    }
}