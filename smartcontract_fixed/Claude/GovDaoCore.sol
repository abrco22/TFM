// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title GovDAOCore (Patched)
 * @notice DAO de gobernanza con membresía acotada, unicidad de miembros,
 *         compute() O(1), control de acceso y gestión de fondos.
 * @dev Fixes: V-01 (MAX_MEMBERS cap), V-02 (isMember mapping),
 *             V-03 (onlyAdmin + join guards), V-04 (compute O(1)),
 *             V-05 (withdraw), V-06 (eventos).
 */
contract GovDAOCore {

    // ─── Constants ────────────────────────────────────────────────────────────

    /**
     * @notice Límite máximo de miembros.
     * @dev    FIX V-01: acota el peor caso de cualquier iteración futura a O(MAX_MEMBERS).
     *         Con MAX_MEMBERS = 500, compute() consume gas acotado y predecible.
     *         Ajustar según necesidades de la DAO.
     */
    uint256 public constant MAX_MEMBERS = 500;

    // ─── State Variables ──────────────────────────────────────────────────────

    /// @notice Autoridad de gobernanza del contrato
    address public admin;

    /// @notice Lista de miembros activos
    address[] public members;

    /// @dev FIX V-02: control O(1) de unicidad de membresía
    mapping(address => bool) public isMember;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-06: trazabilidad completa de operaciones críticas
    event MemberJoined(address indexed member, uint256 totalMembers);
    event MemberAdded(address indexed member, address indexed addedBy, uint256 totalMembers);
    event FundsReceived(address indexed sender, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev FIX V-03: solo el admin puede ejecutar funciones privilegiadas
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() {
        admin = msg.sender;
    }

    // ─── Public Functions ─────────────────────────────────────────────────────

    /**
     * @notice Permite a cualquier dirección unirse a la DAO (permisionless).
     * @dev    FIX V-01: rechaza si se alcanzó MAX_MEMBERS.
     *         FIX V-02: rechaza duplicados via isMember mapping.
     */
    function join() external {
        // FIX V-01: límite de membresía para prevenir DoS por array infinito
        require(members.length < MAX_MEMBERS, "DAO is full");
        // FIX V-02: unicidad — una dirección no puede unirse dos veces
        require(!isMember[msg.sender], "Already a member");

        // CEI: efectos de estado antes de cualquier lógica externa
        isMember[msg.sender] = true;
        members.push(msg.sender);

        emit MemberJoined(msg.sender, members.length); // FIX V-06
    }

    // ─── Admin Functions ──────────────────────────────────────────────────────

    /**
     * @notice El admin puede añadir miembros de forma controlada (DAO privada).
     * @dev    FIX V-03: acceso restringido a onlyAdmin.
     *         FIX V-02: unicidad garantizada.
     * @param user Dirección a incorporar como miembro.
     */
    function addMember(address user) external onlyAdmin {
        require(user != address(0), "Invalid address");
        // FIX V-01: el cap aplica también a adiciones admin
        require(members.length < MAX_MEMBERS, "DAO is full");
        // FIX V-02: unicidad
        require(!isMember[user], "Already a member");

        isMember[user] = true;
        members.push(user);

        emit MemberAdded(user, msg.sender, members.length); // FIX V-06
    }

    /**
     * @notice Retira todos los fondos del contrato al admin.
     * @dev    FIX V-05: previene que ETH quede atrapado permanentemente.
     *         Patrón CEI: estado actualizado antes de la transferencia externa.
     */
    function withdraw() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "Nothing to withdraw");

        // CEI: emit antes del call externo
        emit FundsWithdrawn(admin, balance); // FIX V-06

        (bool ok,) = payable(admin).call{value: balance}("");
        require(ok, "Transfer failed");
    }

    // ─── View Functions ───────────────────────────────────────────────────────

    /**
     * @notice Calcula la suma de (i+j) para todo par (i,j) en [0, n).
     * @dev    FIX V-04: reemplaza el bucle O(n²) por la fórmula cerrada O(1).
     *
     *         Derivación matemática:
     *         ∑_{i=0}^{n-1} ∑_{j=0}^{n-1} (i+j)
     *           = n · ∑_{i=0}^{n-1} i  +  n · ∑_{j=0}^{n-1} j
     *           = 2n · (n·(n-1)/2)
     *           = n² · (n-1)
     *
     * @return Suma total equivalente al doble bucle original.
     */
    function compute() external view returns (uint256) {
        uint256 n = members.length;
        if (n == 0) return 0;

        // FIX V-04: O(1) — sin bucles, gas constante independientemente de n
        return n * n * (n - 1);
    }

    /**
     * @notice Devuelve el número actual de miembros.
     */
    function memberCount() external view returns (uint256) {
        return members.length;
    }

    // ─── Receive ──────────────────────────────────────────────────────────────

    /**
     * @dev    FIX V-05 + V-06: registra recepción de fondos.
     *         El retiro se gestiona mediante withdraw().
     */
    receive() external payable {
        emit FundsReceived(msg.sender, msg.value); // FIX V-06
    }
}