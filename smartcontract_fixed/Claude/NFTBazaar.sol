// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NFTBazaar (Patched)
 * @notice Marketplace multi-listing con propiedad verificada, pull payment,
 *         protección contra reentrancy, reembolso de overpayment y trazabilidad.
 * @dev Fixes: V-01+V-02+V-03 (mapping por id), V-04 (CEI + nonReentrant),
 *             V-05 (overpayment refund), V-06 (ownership check en list),
 *             V-07 (pull payment), V-08 (price guard + eventos).
 */
contract NFTBazaar {

    // ─── Data Structures ──────────────────────────────────────────────────────

    /**
     * @notice Representa un listing activo en el bazar.
     * @dev    FIX V-02: cada tokenId tiene su propio listing independiente.
     */
    struct Listing {
        address seller;
        uint256 price;
        bool    active;
    }

    // ─── State Variables ──────────────────────────────────────────────────────

    /**
     * @notice Propietario actual de cada NFT.
     * @dev    FIX V-06: usado para validar propiedad antes de listar.
     *         address(0) significa que el NFT aún no ha sido reclamado (minteable).
     */
    mapping(uint256 => address) public ownerOf;

    /**
     * @notice Listings activos por tokenId.
     * @dev    FIX V-01+V-02+V-03: reemplaza las variables escalares globales.
     *         Permite múltiples listings simultáneos, cada uno asociado a su id.
     */
    mapping(uint256 => Listing) public listings;

    /**
     * @notice Fondos pendientes de retirar por cada seller.
     * @dev    FIX V-07: patrón pull payment — desacopla la venta del cobro.
     */
    mapping(address => uint256) public pendingWithdrawals;

    /// @dev FIX V-04: mutex de reentrancy guard
    bool private _locked;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-08: trazabilidad completa de todas las operaciones del marketplace
    event Listed(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );
    event ListingCancelled(
        address indexed seller,
        uint256 indexed tokenId
    );
    event Purchased(
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 price,
        address indexed seller
    );
    event ProceedsWithdrawn(
        address indexed seller,
        uint256 amount
    );

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @dev FIX V-04: bloquea cualquier re-entrada directa o cross-function
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    // ─── Seller Functions ─────────────────────────────────────────────────────

    /**
     * @notice Lista un NFT para la venta al precio indicado.
     * @dev    FIX V-01: onlyOwner implícito — solo el propietario del id puede listar.
     *         FIX V-02: listing por id en mapping, no variable global.
     *         FIX V-06: valida propiedad; asigna ownerOf si es primer listing (mint).
     *         FIX V-08: require price > 0 + evento Listed.
     * @param id Identificador del NFT a listar.
     * @param p  Precio de venta en wei (debe ser > 0).
     */
    function list(uint256 id, uint256 p) external {
        // FIX V-08: precio debe ser positivo
        require(p > 0, "Price must be > 0");

        // FIX V-06: validar propiedad del NFT
        // Si ownerOf[id] == address(0), es un mint implícito al primer lister
        if (ownerOf[id] == address(0)) {
            // Mint implícito: el primer lister se convierte en propietario
            ownerOf[id] = msg.sender;
        } else {
            // FIX V-01: solo el propietario actual puede listar
            require(ownerOf[id] == msg.sender, "Not the NFT owner");
        }

        // FIX V-02+V-03: listing vinculado al id específico
        listings[id] = Listing({
            seller: msg.sender,
            price:  p,
            active: true
        });

        emit Listed(msg.sender, id, p); // FIX V-08
    }

    /**
     * @notice Cancela un listing activo del caller.
     * @dev    Solo el seller original puede cancelar su propio listing.
     * @param id Identificador del NFT cuyo listing se cancela.
     */
    function cancelListing(uint256 id) external {
        Listing storage listing = listings[id];
        require(listing.active, "No active listing");
        require(listing.seller == msg.sender, "Not your listing");

        listing.active = false;

        emit ListingCancelled(msg.sender, id); // FIX V-08
    }

    // ─── Buyer Functions ──────────────────────────────────────────────────────

    /**
     * @notice Compra el NFT con el id especificado al precio listado.
     * @dev    FIX V-03: verifica que el listing del id específico esté activo.
     *         FIX V-04: CEI estricto + nonReentrant.
     *         FIX V-05: reembolsa el overpayment al comprador.
     *         FIX V-07: pull payment — acumula fondos para el seller.
     * @param id Identificador del NFT a comprar.
     */
    function buy(uint256 id) external payable nonReentrant {
        Listing storage listing = listings[id];

        // FIX V-03: el listing debe existir y estar activo para este id específico
        require(listing.active, "NFT not listed for sale");
        require(msg.value >= listing.price, "Insufficient payment");

        // ── CEI: capturar estado y actualizarlo ANTES de cualquier interacción ──

        // Capturar valores en memoria antes de modificar storage
        address seller = listing.seller;
        uint256 price  = listing.price;

        // FIX V-04: invalidar listing ANTES de transferencias (previene re-entrada)
        listing.active = false;

        // Transferir propiedad del NFT al comprador
        ownerOf[id] = msg.sender;

        // FIX V-07: acumular fondos para pull payment — sin transferencia directa
        pendingWithdrawals[seller] += price;

        emit Purchased(msg.sender, id, price, seller); // FIX V-08

        // FIX V-05: reembolsar exceso DESPUÉS de actualizar estado (fin del CEI)
        uint256 excess = msg.value - price;
        if (excess > 0) {
            (bool refundOk,) = payable(msg.sender).call{value: excess}("");
            require(refundOk, "Refund failed");
        }
    }

    // ─── Withdrawal Functions ─────────────────────────────────────────────────

    /**
     * @notice El seller retira los fondos acumulados de sus ventas.
     * @dev    FIX V-07: pull payment — elimina DoS por seller que rechaza ETH.
     *         Patrón CEI: balance a 0 ANTES del call externo.
     */
    function withdrawProceeds() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No proceeds to withdraw");

        // CEI: estado a 0 antes de la transferencia externa
        pendingWithdrawals[msg.sender] = 0;

        emit ProceedsWithdrawn(msg.sender, amount); // FIX V-08

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Withdrawal failed");
    }
}