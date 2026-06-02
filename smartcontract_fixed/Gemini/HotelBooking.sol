// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HotelBooking {
    // --- VARIABLES DE ESTADO ---
    address public immutable owner;

    enum RoomType { Single, Double, Suite }

    struct Booking {
        address customer;
        RoomType roomType;
        uint256 bookingDays;
    }

    struct Hotel {
        uint256 basePricePerDay; // En wei
        bool registered;
        Booking[] bookings;
    }

    struct CustomerBooking {
        string hotelName;
        RoomType roomType;
        uint256 bookingDays;
    }

    // Estructuras de datos indexadas para evitar bucles costosos
    mapping(address => CustomerBooking[]) public customerBookings;
    mapping(string => Hotel) public hotels;

    // --- EVENTOS ---
    event HotelRegistered(string indexed hotelName, uint256 basePricePerDay);
    event HotelBooked(string indexed hotelName, address indexed customer, RoomType roomType, uint256 daysBooked, uint256 valuePaid);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    // --- MODIFICADORES ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor() {
        owner = msg.sender;
    }

    // --- FUNCIONES PÚBLICAS / EXTERNAS ---

    /**
     * @notice Registra un hotel nuevo en la plataforma.
     */
    function registerHotel(string memory hotelName, uint256 _basePricePerDay) external onlyOwner {
        require(bytes(hotelName).length > 0, "Hotel name cannot be empty");
        require(!hotels[hotelName].registered, "Hotel already registered");
        require(_basePricePerDay > 0, "Base price per day must be higher than 0");

        hotels[hotelName].basePricePerDay = _basePricePerDay;
        hotels[hotelName].registered = true;

        emit HotelRegistered(hotelName, _basePricePerDay);
    }

    /**
     * @notice Estima el precio total de una reserva.
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
     * @notice Realiza y almacena de forma persistente la reserva de un hotel.
     */
    function bookHotel(string memory hotelName, RoomType _roomType, uint256 _bookingDays) external payable {
        require(hotels[hotelName].registered, "Hotel not registered");
        require(_bookingDays > 0, "Booking days must be higher than 0");
        
        uint256 requiredPrice = estimateBookingPrice(hotelName, _roomType, _bookingDays);
        require(msg.value >= requiredPrice, "Not enough weis");

        // FIX: Guardar la información de forma persistente en Storage global
        hotels[hotelName].bookings.push(Booking({
            customer: msg.sender,
            roomType: _roomType,
            bookingDays: _bookingDays
        }));

        customerBookings[msg.sender].push(CustomerBooking({
            hotelName: hotelName,
            roomType: _roomType,
            bookingDays: _bookingDays
        }));

        emit HotelBooked(hotelName, msg.sender, _roomType, _bookingDays, msg.value);
    }

    /**
     * @notice Devuelve el historial de reservas de un cliente en un hotel sin costo de gas excesivo.
     */
    function getCustomerBookings(string memory hotelName, address customer) external view returns (Booking[] memory) {
        require(hotels[hotelName].registered, "Hotel not registered");

        Booking[] storage allBookings = hotels[hotelName].bookings;
        uint256 count = 0;

        for (uint256 i = 0; i < allBookings.length; i++) {
            if (allBookings[i].customer == customer) {
                count++;
            }
        }

        Booking[] memory customerFiltered = new Booking[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allBookings.length; i++) {
            if (allBookings[i].customer == customer) {
                customerFiltered[index] = allBookings[i];
                index++;
            }
        }

        return customerFiltered;
    }

    /**
     * @notice Permite al administrador retirar las ganancias acumuladas por las reservas.
     */
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available");

        (bool ok, ) = payable(owner).call{value: balance}("");
        require(ok, "Transfer failed");

        emit FundsWithdrawn(owner, balance);
    }
}
