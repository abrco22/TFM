// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HotelBooking {
    // Variables
    address public owner;
    uint public withdrawableBalance;

    bool private locked;

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

    event HotelRegistered(string indexed hotelName, uint basePricePerDay);
    event HotelBooked(
        string indexed hotelName,
        address indexed customer,
        RoomType roomType,
        uint bookingDays,
        uint price
    );
    event RefundIssued(address indexed customer, uint amount);
    event Withdrawn(address indexed owner, uint amount);

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

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    // Functions
    function registerHotel(
        string memory hotelName,
        uint _basePricePerDay
    ) public onlyOwner {
        require(bytes(hotelName).length > 0, "Invalid hotel name");
        require(!hotels[hotelName].registered, "Hotel already registered");
        require(
            _basePricePerDay > 0,
            "Base price per day must be higher than 0"
        );

        hotels[hotelName].basePricePerDay = _basePricePerDay;
        hotels[hotelName].registered = true;

        emit HotelRegistered(hotelName, _basePricePerDay);
    }

    function estimateBookingPrice(
        string memory hotelName,
        RoomType _roomType,
        uint _bookingDays
    ) public view returns (uint) {
        require(hotels[hotelName].registered, "Hotel not registered");
        require(_bookingDays > 0, "Booking days must be higher than 0");

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
    ) public payable nonReentrant {
        require(hotels[hotelName].registered, "Hotel not registered");
        require(_bookingDays > 0, "Booking days must be higher than 0");

        uint price = estimateBookingPrice(hotelName, _roomType, _bookingDays);
        require(msg.value >= price, "Not enough weis");

        Booking memory b = Booking({
            customer: msg.sender,
            roomType: _roomType,
            bookingDays: _bookingDays
        });

        hotels[hotelName].bookings.push(b);

        customerBookings[msg.sender].push(
            CustomerBooking({
                hotelName: hotelName,
                roomType: _roomType,
                bookingDays: _bookingDays
            })
        );

        withdrawableBalance += price;

        uint refund = msg.value - price;
        if (refund > 0) {
            (bool refundOk,) = payable(msg.sender).call{value: refund}("");
            require(refundOk, "Refund failed");

            emit RefundIssued(msg.sender, refund);
        }

        emit HotelBooked(hotelName, msg.sender, _roomType, _bookingDays, price);
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
        require(customer != address(0), "Invalid customer");

        Booking[] storage allBookings = hotels[hotelName].bookings;

        uint count = 0;
        for (uint i = 0; i < allBookings.length; i++) {
            if (allBookings[i].customer == customer) {
                count++;
            }
        }

        Booking[] memory result = new Booking[](count);

        uint index = 0;
        for (uint i = 0; i < allBookings.length; i++) {
            if (allBookings[i].customer == customer) {
                result[index] = allBookings[i];
                index++;
            }
        }

        return result;
    }

    function withdraw(uint amount) external onlyOwner nonReentrant {
        require(amount > 0, "Invalid amount");
        require(withdrawableBalance >= amount, "Insufficient withdrawable balance");

        withdrawableBalance -= amount;

        (bool ok,) = payable(owner).call{value: amount}("");
        require(ok, "Withdraw failed");

        emit Withdrawn(owner, amount);
    }

    receive() external payable {
        revert("Direct ETH not accepted");
    }
}