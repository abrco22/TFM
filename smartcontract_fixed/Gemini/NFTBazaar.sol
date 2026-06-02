// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NFTBazaar {
    // --- ESTRUCTURAS DE DATOS ---
    struct Listing {
        address seller;
        uint256 price;
        bool isListed;
    }

    // Mapeos independientes para evitar colisiones de estado global
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => Listing) public listings;

    // --- EVENTOS ---
    event NFTMinted(uint256 indexed id, address indexed owner);
    event NFTListed(uint256 indexed id, address indexed seller, uint256 price);
    event NFTSold(uint256 indexed id, address indexed buyer, address indexed seller, uint256 price);
    event ListingCanceled(uint256 indexed id, address indexed seller);

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Función auxiliar para simular la creación/posesión inicial de un NFT en el bazar.
     */
    function mint(uint256 id) external {
        require(ownerOf[id] == address(0), "NFT already exists");
        ownerOf[id] = msg.sender;
        emit NFTMinted(id, msg.sender);
    }

    /**
     * @notice Lista un NFT específico para la venta de manera aislada y segura.
     * @param id Identificador único del NFT.
     * @param p Precio de venta en wei.
     */
    function list(uint256 id, uint256 p) external {
        // Control de acceso: Solo el dueño real del token puede listarlo
        require(ownerOf[id] == msg.sender, "Not authorized: You do not own this NFT");
        require(p > 0, "Price must be greater than zero");

        listings[id] = Listing({
            seller: msg.sender,
            price: p,
            isListed: true
        });

        emit NFTListed(id, msg.sender, p);
    }

    /**
     * @notice Permite comprar un NFT listado pagando el precio exacto requerido.
     * @param id Identificador único del NFT que se desea adquirir.
     */
    function buy(uint256 id) external payable {
        Listing memory targetListing = listings[id];
        
        // 1. CHECKS
        require(targetListing.isListed, "NFT is not listed for sale");
        require(msg.value >= targetListing.price, "Insufficient funds sent");

        address targetSeller = targetListing.seller;
        uint256 salePrice = targetListing.price;

        // 2. EFFECTS (Patrón CEI: Modificar el estado antes de interactuar con el exterior)
        // Eliminar listado y actualizar dueño para prevenir ataques de reentrada de listado masivo
        delete listings[id]; 
        ownerOf[id] = msg.sender;

        // Devuelve el cambio sobrante al comprador si envió de más
        uint256 refund = msg.value - salePrice;
        if (refund > 0) {
            (bool refundOk, ) = payable(msg.sender).call{value: refund}("");
            require(refundOk, "Refund failed");
        }

        // 3. INTERACTIONS
        (bool ok, ) = payable(targetSeller).call{value: salePrice}("");
        require(ok, "Transfer to seller failed");

        emit NFTSold(id, msg.sender, targetSeller, salePrice);
    }

    /**
     * @notice Permite al propietario cancelar un listado activo.
     */
    function cancelListing(uint256 id) external {
        require(listings[id].isListed, "Listing does not exist");
        require(listings[id].seller == msg.sender, "Not authorized: Only the seller can cancel");

        delete listings[id];
        emit ListingCanceled(id, msg.sender);
    }
}
