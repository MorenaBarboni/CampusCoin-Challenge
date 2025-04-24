// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../@openzeppelin/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract CampusCoin is ERC20 {
    address public admin;
    address public university;

    struct Student {
        bool active;
        uint256 totalSpent;
    }

    mapping(address => Student) public students;

    struct ServiceProvider {
        string name;
        string category;
        bool active;
    }

    struct Service {
        string name;
        uint256 price;
        uint256 discount; // 0-100%
        bool active;
    }

    mapping(address => ServiceProvider) public serviceProviders;
    mapping(address => mapping(bytes32 => Service)) public services;

    // === EVENTS ===
    event StudentAdded(address indexed student);
    event StudentRemoved(address indexed student);
    event ServiceProviderAdded(address indexed provider, string name, string category);
    event ServiceProviderUpdated(address indexed provider, string newName, string newCategory, bool active);
    event ServiceProviderRemoved(address indexed provider);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event ServicePaid(address indexed student, address indexed provider, uint256 amount, uint256 fee, bytes32 serviceId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this");
        _;
    }

    modifier onlyActiveProvider() {
        require(serviceProviders[msg.sender].active, "Only active providers");
        _;
    }

    modifier onlyActiveStudent(address student) {
        require(students[student].active, "Only registered students allowed");
        _;
    }

    constructor(address _university) ERC20("CampusCoin", "CC") {
        admin = msg.sender;
        university = _university;
        _mint(msg.sender, 3_000 * 10 ** decimals());
    }

    // === MINTING, BURNING AND TRANSFERING TOKENS ===
    function mint(address to, uint256 amount) public onlyAdmin onlyActiveStudent(to) {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    function transfer(address to, uint256 amount) public override onlyActiveStudent(to) returns (bool) {
        return super.transfer(to, amount);
    }

    // === STUDENT MANAGEMENT ===
    function addStudent(address student) external onlyAdmin {
        students[student].active = true;
        emit StudentAdded(student);
    }

    function removeStudent(address student) external onlyAdmin {
        students[student].active = false;
        emit StudentRemoved(student);
    }

    // === SERVICE PROVIDER MANAGEMENT ===
    function addServiceProvider(address provider, string calldata name, string calldata category) external onlyAdmin {
        serviceProviders[provider] = ServiceProvider(name, category, true);
        emit ServiceProviderAdded(provider, name, category);
    }

    function removeServiceProvider(address provider) external onlyAdmin {
        serviceProviders[provider].active = false;
        emit ServiceProviderRemoved(provider);
    }

    function updateServiceProvider(address provider, string calldata newName, string calldata newCategory, bool active) external onlyAdmin {
        require(bytes(serviceProviders[provider].name).length > 0, "Provider not found");
        serviceProviders[provider] = ServiceProvider(newName, newCategory, active);
        emit ServiceProviderUpdated(provider, newName, newCategory, active);
    }

    // === SERVICE MANAGEMENT ===
    function addService(bytes32 serviceId, string calldata name, uint256 price) external onlyActiveProvider {
        services[msg.sender][serviceId] = Service(name, price, 0, true);
    }

    function removeService(bytes32 serviceId) external onlyActiveProvider {
        services[msg.sender][serviceId].active = false;
    }

    function updateService(bytes32 serviceId, string calldata newName, uint256 newPrice, bool active) external onlyActiveProvider {
        Service storage s = services[msg.sender][serviceId];
        require(bytes(s.name).length > 0, "Service doesn't exist");
        s.name = newName;
        s.price = newPrice;
        s.active = active;
    }

    function setServiceDiscount(bytes32 serviceId, uint256 discount) external onlyActiveProvider {
        require(discount <= 100, "Invalid discount");
        services[msg.sender][serviceId].discount = discount;
    }

    // === PAY FOR SPECIFIC SERVICE ===
    function payForService(address provider, bytes32 serviceId) external onlyActiveStudent(msg.sender) {
        require(serviceProviders[provider].active, "Inactive provider");

        Service memory s = services[provider][serviceId];
        require(s.active, "Service not available");

        uint256 discountedPrice = s.price - (s.price * s.discount / 100);
        uint256 fee = discountedPrice / 100; // 1%
        uint256 amountAfterFee = discountedPrice - fee;

        _transfer(msg.sender, university, fee);
        _transfer(msg.sender, provider, amountAfterFee);

        students[msg.sender].totalSpent += discountedPrice;

        emit ServicePaid(msg.sender, provider, amountAfterFee, fee, serviceId);
    }
}
