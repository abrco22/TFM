// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HotelBooking (Patched)
 * @notice Sistema de reservas hoteleras on-chain con persistencia correcta,
 *         gestión de fondos, devolución de overpayment e índices eficientes.
 * @dev Fixes: V-01 (push a storage), V-02 (withdraw), V-03 (refund overpayment),
 *             V-04 (customerBookings poblado), V-05 (lookup O(1)),
 *             V-06 (hotelName validation), V-07 (eventos).
 */
contract HotelBooking {

    // ─── State Variables ──────────────────────────────────────────────────────

    address public owner;

    // ─── Data Structures ──────────────────────────────────────────────────────

    struct Hotel {
        uint256 basePricePerDay; // In wei
        bool    registered;
        Booking[] bookings;
    }

    struct Booking {
        address customer;
        RoomType roomType;
        uint256 bookingDays;
    }

    enum RoomType {
        Single,  // multiplier x1
        Double,  // multiplier x2
        Suite    // multiplier x3
    }

    struct CustomerBooking {
        string   hotelName;
        RoomType roomType;
        uint256  bookingDays;
    }

    // ─── Mappings ─────────────────────────────────────────────────────────────

    /// @notice Historial de reservas por cliente (índice O(1))
    /// @dev    FIX V-04: ahora se puebla correctamente en bookHotel()
    mapping(address => CustomerBooking[]) public customerBookings;

    /// @notice Información de cada hotel por nombre
    mapping(string => Hotel) public hotels;

    // ─── Events ───────────────────────────────────────────────────────────────

    // FIX V-07: trazabilidad completa de operaciones críticas
    event HotelRegistered(string indexed hotelName, uint256 basePricePerDay);
    event BookingCreated(
        address indexed customer,
        string  hotelName,
        RoomType roomType,
        uint256 bookingDays,
        uint256 pricePaid
    );
    event FundsWithdrawn(address indexed to, uint256 amount);

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    // ─── Owner Functions ──────────────────────────────────────────────────────

    /**
     * @notice Registra un nuevo hotel con su precio base por día.
     * @dev    FIX V-06: valida que hotelName no sea vacío.
     * @param hotelName       Nombre único del hotel (no vacío).
     * @param _basePricePerDay Precio base en wei por noche (debe ser > 0).
     */
    function registerHotel(
        string memory hotelName,
        uint256 _basePricePerDay
    ) public onlyOwner {
        // FIX V-06: nombre de hotel no puede ser vacío
        require(bytes(hotelName).length > 0, "Hotel name cannot be empty");
        require(!hotels[hotelName].registered, "Hotel already registered");
        require(
            _basePricePerDay > 0,
            "Base price per day must be higher than 0"
        );

        hotels[hotelName].basePricePerDay = _basePricePerDay;
        hotels[hotelName].registered      = true;

        emit HotelRegistered(hotelName, _basePricePerDay); // FIX V-07
    }

    /**
     * @notice Retira todos los fondos acumulados al owner.
     * @dev    FIX V-02: previene que ETH quede atrapado permanentemente.
     *         Patrón CEI: emit antes del call externo.
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        emit FundsWithdrawn(owner, balance); // FIX V-07

        (bool ok,) = payable(owner).call{value: balance}("");
        require(ok, "Transfer failed");
    }

    // ─── Public Functions ─────────────────────────────────────────────────────

    /**
     * @notice Calcula el precio estimado de una reserva.
     * @param hotelName    Nombre del hotel.
     * @param _roomType    Tipo de habitación (Single=x1, Double=x2, Suite=x3).
     * @param _bookingDays Número de noches.
     * @return Precio total en wei.
     */
    function estimateBookingPrice(
        string memory hotelName,
        RoomType _roomType,
        uint256 _bookingDays
    ) public view returns (uint256) {
        uint256 multiplier = 1;
        if (_roomType == RoomType.Double) {
            multiplier = 2;
        } else if (_roomType == RoomType.Suite) {
            multiplier = 3;
        }
        return hotels[hotelName].basePricePerDay * multiplier * _bookingDays;
    }

    /**
     * @notice Realiza una reserva en el hotel especificado.
     * @dev    FIX V-01: reserva persiste en storage via push().
     *         FIX V-03: devuelve overpayment al usuario (CEI).
     *         FIX V-04: puebla customerBookings para índice O(1).
     *         FIX V-06: valida hotelName no vacío.
     *         FIX V-07: emite BookingCreated.
     * @param hotelName    Nombre del hotel registrado.
     * @param _roomType    Tipo de habitación deseada.
     * @param _bookingDays Número de noches a reservar.
     */
    function bookHotel(
        string memory hotelName,
        RoomType _roomType,
        uint256 _bookingDays
    ) public payable {
        // FIX V-06: nombre de hotel no puede ser vacío
        require(bytes(hotelName).length > 0, "Hotel name cannot be empty");
        require(hotels[hotelName].registered, "Hotel not registered");
        require(_bookingDays > 0, "Booking days must be higher than 0");

        uint256 price = estimateBookingPrice(hotelName, _roomType, _bookingDays);
        require(msg.value >= price, "Not enough wei sent");

        // ── CEI: efectos de estado ANTES de cualquier interacción externa ──

        // FIX V-01: persistir la reserva en el storage del hotel
        hotels[hotelName].bookings.push(Booking({
            customer:    msg.sender,
            roomType:    _roomType,
            bookingDays: _bookingDays
        }));

        // FIX V-04: actualizar el índice por cliente para consultas O(1)
        customerBookings[msg.sender].push(CustomerBooking({
            hotelName:   hotelName,
            roomType:    _roomType,
            bookingDays: _bookingDays
        }));

        emit BookingCreated(        // FIX V-07
            msg.sender,
            hotelName,
            _roomType,
            _bookingDays,
            price
        );

        // FIX V-03: devolver el exceso de pago al usuario (interacción externa al final)
        uint256 excess = msg.value - price;
        if (excess > 0) {
            (bool ok,) = payable(msg.sender).call{value: excess}("");
            require(ok, "Refund failed");
        }
    }

    /**
     * @notice Devuelve todas las reservas de un cliente en un hotel específico.
     * @dev    FIX V-05: redirige a customerBookings para O(1) cuando se filtra
     *         por cliente. Si se necesita filtrar por hotel además, se mantiene
     *         el filtro pero sobre el array del cliente (generalmente mucho menor).
     * @param hotelName Nombre del hotel.
     * @param customer  Dirección del cliente.
     * @return Array de reservas del cliente en ese hotel.
     */
    function getCustomerBookings(
        string memory hotelName,
        address customer
    ) public view returns (CustomerBooking[] memory) {
        require(hotels[hotelName].registered, "Hotel not registered");
        require(customer != address(0), "Invalid customer address");

        // FIX V-05: iteramos sobre el array del cliente (típicamente pequeño)
        // en lugar de iterar todos los bookings del hotel (potencialmente enorme)
        CustomerBooking[] storage allCustomerBookings = customerBookings[customer];

        uint256 count = 0;
        for (uint256 i = 0; i < allCustomerBookings.length; i++) {
            if (
                keccak256(bytes(allCustomerBookings[i].hotelName)) ==
                keccak256(bytes(hotelName))
            ) {
                count++;
            }
        }

        CustomerBooking[] memory result = new CustomerBooking[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allCustomerBookings.length; i++) {
            if (
                keccak256(bytes(allCustomerBookings[i].hotelName)) ==
                keccak256(bytes(hotelName))
            ) {
                result[index] = allCustomerBookings[i];
                index++;
            }
        }
        return result;
    }

    /**
     * @notice Devuelve todas las reservas de un cliente en todos los hoteles.
     * @dev    Lectura directa del índice O(1) por cliente.
     * @param customer Dirección del cliente.
     * @return Array de todas las reservas del cliente.
     */
    function getAllCustomerBookings(
        address customer
    ) public view returns (CustomerBooking[] memory) {
        require(customer != address(0), "Invalid customer address");
        return customerBookings[customer];
    }
}