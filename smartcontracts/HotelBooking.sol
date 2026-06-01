// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HotelBooking {
    // Variables
    address public owner;

    // Data structures
    struct Hotel {
        uint basePricePerDay; // In weis
        bool registered;
        Booking[] bookings;
    }

    struct Booking {
        address customer;
        RoomType roomType;
        uint bookingDays;
    }

    enum RoomType {
        Single,
        Double,
        Suite
    }

    struct CustomerBooking {
        string hotelName;
        RoomType roomType;
        uint bookingDays;
}
    // Reservas 
    mapping(address => CustomerBooking[]) public customerBookings;

    // Hotel information (mapping)
    mapping(string => Hotel) public hotels;

    constructor() {
        owner = msg.sender;
    }

    // Modifiers
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    // Functions
    function registerHotel(
        string memory hotelName,
        uint _basePricePerDay
    ) public onlyOwner {
        require(!hotels[hotelName].registered, "Hotel already registered");
        require(
            _basePricePerDay > 0,
            "Base price per day must be higher than 0"
        );

        hotels[hotelName].basePricePerDay = _basePricePerDay;
        hotels[hotelName].registered = true;
    }
    function estimateBookingPrice(
        string memory hotelName,
        RoomType _roomType,
        uint _bookingDays
    ) public view returns (uint) {
        uint multiplier = 1;

        if (_roomType == RoomType.Double) {
            multiplier = 2;
        } else if (_roomType == RoomType.Suite) {
            multiplier = 3;
        }

        return hotels[hotelName].basePricePerDay * multiplier * _bookingDays;
    }

    function bookHotel(
        string memory hotelName,
        RoomType _roomType,
        uint _bookingDays
    ) public payable {
        require(hotels[hotelName].registered, "Hotel not registered");
        require(_bookingDays > 0, "Booking days must be higher than 0");
        require(
            msg.value >=
                estimateBookingPrice(hotelName, _roomType, _bookingDays),
            "Not enough weis"
        );

        Booking memory b;
        b.customer = msg.sender;
        b.roomType = _roomType;
        b.bookingDays = _bookingDays;
    }

    function getCustomerBookings(
        string memory hotelName,
        address customer
    )
        public
        view
        returns (Booking[] memory)
    {
        require(hotels[hotelName].registered, "Hotel not registered");

        Booking[] storage allBookings = hotels[hotelName].bookings;

        uint count = 0;
        for (uint i = 0; i < allBookings.length; i++) {
            if (allBookings[i].customer == customer) {
                count++;
            }
        }

        Booking[] memory customerBookings = new Booking[](count);

        uint index = 0;
        for (uint i = 0; i < allBookings.length; i++) {
            if (allBookings[i].customer == customer) {
                customerBookings[index] = allBookings[i];
                index++;
            }
        }

        return customerBookings;
    }
}