// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleAuction {
    // --- ESTADO ---
    address public immutable seller;
    uint256 public highestBid;
    address public highestBidder;
    bool public ended;

    // Seguimiento seguro de los fondos a devolver (Patrón Pull-Payment)
    mapping(address => uint256) public pendingReturns;

    // --- EVENTOS ---
    event NewBid(address indexed bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event Withdrawal(address indexed bidder, uint256 amount);

    // --- CONSTRUCTOR ---
    constructor() {
        seller = msg.sender;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Permite realizar una oferta económica para la subasta.
     */
    function bid() external payable {
        require(!ended, "Auction ended");
        require(msg.value > highestBid, "Bid too low");

        // Efecto: Registrar el reembolso del postor anterior si existía uno
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        // Actualizar el estado con el nuevo líder
        highestBid = msg.value;
        highestBidder = msg.sender;

        emit NewBid(msg.sender, msg.value);
    }

    /**
     * @notice Permite a los postores superados retirar sus fondos por sí mismos.
     */
    function withdraw() external returns (bool) {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        // Checks-Effects-Interactions: Resetear saldo antes de transferir
        pendingReturns[msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        if (!ok) {
            // Revertir el estado si falla la transferencia externa
            pendingReturns[msg.sender] = amount;
            return false;
        }

        emit Withdrawal(msg.sender, amount);
        return true;
    }

    /**
     * @notice Finaliza la subasta y envía la puja más alta al vendedor.
     */
    function endAuction() external {
        require(msg.sender == seller, "Only seller");
        require(!ended, "Auction already ended");

        // Efecto: Marcar como finalizado antes de la llamada externa
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        // Interacción: Envío de fondos acumulados de la puja ganadora
        if (highestBid > 0) {
            (bool ok, ) = payable(seller).call{value: highestBid}("");
            require(ok, "Transfer to seller failed");
        }
    }
}