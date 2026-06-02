// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SecureVoteMultiSig (Patched)
 * @notice Multisig wallet con control de acceso en aprobaciones y ejecuciones,
 *         protección contra replay attacks, CEI estricto, nonce por transacción
 *         y trazabilidad completa.
 * @dev Fixes: V-01 (isOwner en approve), V-02 (constructor guards),
 *             V-03 (executed mapping), V-04 (CEI + nonReentrant),
 *             V-05 (onlyOwner en execute), V-06 (receive),
 *             V-07 (MAX_OWNERS cap), V-08 (nonce), V-09 (eventos).
 */
contract SecureVoteMultiSig {

    // ─── Constants ────────────────────────────────────────────────────────────

    /**
     * @notice Límite máximo de owners para acotar el gas del bucle en execute().
     * @dev    FIX V-07: con 50 owners, el bucle consume gas predecible y seguro.
     */
    uint256 public constant MAX_OWNERS = 50;

    // ─── State Variables ──────────────────────────────────────────────────────

    /// @notice Lista de owners del multisig
    address[] public owners;

    /// @notice Número de aprobaciones requeridas para ejecutar una transacción
    uint256 public required;

    /**
     * @notice Nonce incremental para garantizar unicidad de cada txHash.
     * @dev    FIX V-08: cada propuesta consume un nonce distinto,
     *         eliminando colisiones entre transacciones con mismos parámetros.
     */
    uint256 public nonce;

    /// @dev FIX V-01: lookup O(1) para verificar membresía en approve() y execute()
    mapping(address => bool) public isOwner;

    /// @dev FIX V-01+V-03: aprobaciones por txHash y por owner
    mapping(bytes32 => mapping(address => bool)) public approvals;

    /**
     * @notice Registra qué txHash ya han sido ejecutados.
     * @dev    FIX V-03: previene replay attacks — cada txHash ejecutable exactamente una vez.
     */
    mapping(bytes32 => bool) public executed;

    /// @dev FIX V-04: mutex contra reentrancy directa y cross-function
    bool private _locked;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-09: trazabilidad completa del ciclo de vida del multisig
    event OwnerAdded(address indexed owner);
    event TransactionApproved(
        address indexed owner,
        bytes32 indexed txHash,
        uint256 approvalCount
    );
    event TransactionExecuted(
        address indexed executor,
        bytes32 indexed txHash,
        address indexed to,
        uint256 value
    );
    event EthReceived(address indexed sender, uint256 amount);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev FIX V-01 + V-05: solo owners registrados pueden aprobar y ejecutar
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    /// @dev FIX V-04: bloquea cualquier re-entrada directa o cross-function
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param o Array de owners del multisig (sin duplicados, sin zero-address).
     * @param r Número de aprobaciones requeridas (0 < r <= o.length).
     */
    constructor(address[] memory o, uint256 r) {
        // FIX V-02: validaciones exhaustivas de parámetros de construcción
        require(o.length > 0,              "At least one owner required");
        require(o.length <= MAX_OWNERS,    "Exceeds MAX_OWNERS");          // FIX V-07
        require(r > 0,                     "Required must be > 0");
        require(r <= o.length,             "Required exceeds owner count");

        for (uint256 i = 0; i < o.length; i++) {
            address owner = o[i];
            // FIX V-02: no zero-address
            require(owner != address(0), "Invalid owner: zero address");
            // FIX V-02: no duplicados
            require(!isOwner[owner],     "Duplicate owner detected");

            isOwner[owner] = true;
            owners.push(owner);

            emit OwnerAdded(owner); // FIX V-09
        }

        required = r;
    }

    // ─── Owner Functions ──────────────────────────────────────────────────────

    /**
     * @notice Registra la aprobación del caller para un txHash específico.
     * @dev    FIX V-01: restringido a onlyOwner — solo owners pueden aprobar.
     *         FIX V-03: no puede aprobar un txHash ya ejecutado.
     * @param txHash Hash de la transacción a aprobar.
     */
    function approve(bytes32 txHash) external onlyOwner {
        // FIX V-03: no tiene sentido aprobar una transacción ya ejecutada
        require(!executed[txHash], "Transaction already executed");
        require(!approvals[txHash][msg.sender], "Already approved");

        approvals[txHash][msg.sender] = true;

        // Contar aprobaciones actuales para el evento
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (approvals[txHash][owners[i]]) count++;
        }

        emit TransactionApproved(msg.sender, txHash, count); // FIX V-09
    }

    /**
     * @notice Ejecuta una transacción si tiene suficientes aprobaciones.
     * @dev    FIX V-03: require(!executed[txHash]) — no replay posible.
     *         FIX V-04: executed[txHash] = true ANTES del .call{} (CEI) + nonReentrant.
     *         FIX V-05: restringido a onlyOwner.
     *         FIX V-08: txHash debe generarse con el nonce correcto off-chain
     *                   via keccak256(abi.encodePacked(to, value, data, nonce, address(this))).
     * @param to      Dirección destinataria de la transacción.
     * @param value   Valor en wei a transferir.
     * @param data    Calldata para la llamada externa.
     * @param txNonce Nonce que se usó para generar el txHash (debe coincidir con nonce actual).
     * @param txHash  Hash de la transacción: keccak256(to, value, data, nonce, address(this)).
     */
    function execute(
        address to,
        uint256 value,
        bytes  calldata data,
        uint256 txNonce,
        bytes32 txHash
    ) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid target address");

        // FIX V-08: verificar que el txHash corresponde exactamente a los parámetros
        // y al nonce actual, previniendo colisiones y reutilización cross-contexto
        require(
            txHash == keccak256(
                abi.encodePacked(to, value, data, txNonce, address(this))
            ),
            "Hash mismatch"
        );
        require(txNonce == nonce, "Invalid nonce");

        // FIX V-03: verificar que esta transacción no ha sido ejecutada antes
        require(!executed[txHash], "Transaction already executed");

        // Verificar umbral de aprobaciones
        uint256 count;
        for (uint256 i = 0; i < owners.length; i++) {
            if (approvals[txHash][owners[i]]) {
                count++;
            }
        }
        require(count >= required, "Insufficient approvals");

        // ── CEI: todo el estado actualizado ANTES de la llamada externa ────────

        // FIX V-03 + V-04: marcar como ejecutado ANTES del .call{}
        executed[txHash] = true;

        // FIX V-08: incrementar nonce para invalidar cualquier hash futuro
        // que intente reutilizar el nonce actual
        nonce++;

        emit TransactionExecuted(msg.sender, txHash, to, value); // FIX V-09

        // ── Interacción: llamada externa al final del flujo ───────────────────
        (bool ok,) = payable(to).call{value: value}(data);
        require(ok, "Transaction execution failed");
    }

    // ─── View Functions ───────────────────────────────────────────────────────

    /**
     * @notice Devuelve el número de aprobaciones actuales para un txHash.
     * @param txHash Hash de la transacción a consultar.
     */
    function getApprovalCount(bytes32 txHash)
        external
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < owners.length; i++) {
            if (approvals[txHash][owners[i]]) count++;
        }
    }

    /**
     * @notice Calcula el txHash correcto para los parámetros dados y el nonce actual.
     * @dev    Helper para que los owners generen el hash correcto off-chain o en tests.
     */
    function computeTxHash(
        address to,
        uint256 value,
        bytes calldata data
    ) external view returns (bytes32) {
        return keccak256(abi.encodePacked(to, value, data, nonce, address(this)));
    }

    // ─── Receive ──────────────────────────────────────────────────────────────

    /**
     * @notice Permite al multisig recibir ETH para custodiar y distribuir.
     * @dev    FIX V-06: sin receive(), execute() con value > 0 siempre fallaría.
     */
    receive() external payable {
        emit EthReceived(msg.sender, msg.value); // FIX V-09
    }
}