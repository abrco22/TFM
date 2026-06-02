// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SecureVoteMultiSig {
    // --- ESTADO ---
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;
    uint256 public nonce;

    // txHash => owner => aprobado
    mapping(bytes32 => mapping(address => bool)) public approvals;
    // txHash => ejecutado
    mapping(bytes32 => bool) public executed;

    // --- EVENTOS ---
    event Approved(bytes32 indexed txHash, address indexed owner);
    event Executed(bytes32 indexed txHash, address indexed to, uint256 value);

    // --- MODIFICADORES ---
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor(address[] memory o, uint256 r) {
        require(o.length > 0, "Owners required");
        require(r > 0 && r <= o.length, "Invalid number of required signatures");

        for (uint256 i = 0; i < o.length; i++) {
            address owner = o[i];
            require(owner != address(0), "Invalid owner address");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
        }
        owners = o;
        required = r;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Permite a un propietario aprobar un hash de transacción específico.
     * @param txHash Hash de los datos de la transacción generado externamente o mediante getTxHash.
     */
    function approve(bytes32 txHash) external onlyOwner {
        require(!executed[txHash], "Transaction already executed");
        require(!approvals[txHash][msg.sender], "Transaction already approved by this owner");

        approvals[txHash][msg.sender] = true;
        emit Approved(txHash, msg.sender);
    }

    /**
     * @notice Ejecuta una transacción si cuenta con el número de aprobaciones requeridas.
     * @param to Dirección destino de la transferencia o interacción.
     * @param value Cantidad de wei a enviar.
     * @param txNonce Nonce específico de esta transacción para evitar colisiones/replays.
     */
    function execute(address to, uint256 value, uint256 txNonce) external onlyOwner {
        require(txNonce == nonce, "Invalid nonce sequence");
        
        // Reconstrucción y validación estricta del hash de la transacción
        bytes32 txHash = getTxHash(to, value, txNonce);
        
        require(!executed[txHash], "Transaction already executed");

        uint256 count;
        for (uint256 i = 0; i < owners.length; i++) {
            if (approvals[txHash][owners[i]]) {
                count++;
            }
        }

        require(count >= required, "Not enough approvals");

        // Efecto: Cambiar el estado antes de la llamada externa (Checks-Effects-Interactions)
        executed[txHash] = true;
        nonce++; // Incremento secuencial del nonce global

        // Interacción
        (bool ok, ) = payable(to).call{value: value}("");
        require(ok, "Transaction execution failed");

        emit Executed(txHash, to, value);
    }

    /**
     * @notice Función helper para calcular de forma determinista el hash de una transacción.
     */
    function getTxHash(address to, uint256 value, uint256 txNonce) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), to, value, txNonce));
    }

    // Permitir la recepción de fondos
    receive() external payable {}
}