// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../@openzeppelin/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
/**
 * @title CampusCoin
 * @dev A custom ERC20 token for campus ecosystems, allowing students to purchase services from approved providers.
 */
contract CampusCoin is ERC20 {
    address public admin;
    address public university;

    struct Student {
        bool active;
        uint256 totalSpent;
        StudentTier tier;
    }

    mapping(address => Student) public students;

    enum StudentTier { Bronze, Silver, Gold }

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
    mapping(address => mapping(uint256 => Service)) public services;

    uint256 public feePercentage; // Fee in basis points (1% = 100)

    // === EVENTS ===
    event AirdropExecuted(address indexed student, uint256 amount);
    event StudentAdded(address indexed student);
    event StudentRemoved(address indexed student);
    event StudentTierUpdated(address indexed student, StudentTier newTier);
    event ServiceProviderAdded(address indexed provider, string name, string category);
    event ServiceProviderUpdated(address indexed provider, string newName, string newCategory, bool active);
    event ServiceProviderRemoved(address indexed provider);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event ServicePaid(address indexed student, address indexed provider, uint256 amount, uint256 fee, uint256 serviceId);
    event FeePercentageUpdated(uint256 newFeePercentage);

    // === ACCESS CONTROL MODIFIERS ===

    /**
     * @dev Restricts function to admin only.
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this");
        _;
    }

    /**
     * @dev Restricts function to active service providers only.
     */
    modifier onlyActiveProvider() {
        require(serviceProviders[msg.sender].active, "Only active providers");
        _;
    }

    /**
     * @dev Restricts function to active students only.
     * @param student Address of the student.
     */
    modifier onlyActiveStudent(address student) {
        require(students[student].active, "Only registered students allowed");
        _;
    }

    // === CONSTRUCTOR ===

    /**
     * @dev Initializes the CampusCoin contract.
     * @param _university Address of the university.
     */
    constructor(address _university) ERC20("CampusCoin", "CC") {
        admin = msg.sender;
        university = _university;
        _mint(msg.sender, 3_000 * 10 ** decimals());
        feePercentage = 100; // Default to 1% fee
    }

    // === MINTING, BURNING, AND TRANSFERING TOKENS ===

    /**
     * @dev Mints tokens to a student's account.
     * @param to Address to receive tokens.
     * @param amount Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyAdmin onlyActiveStudent(to) {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Burns tokens from the caller's account.
     * @param amount Amount of tokens to burn.
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @dev Transfers tokens to another active student.
     * @param to Address of the recipient.
     * @param amount Amount of tokens to transfer.
     */
    function transfer(address to, uint256 amount) public override onlyActiveStudent(to) returns (bool) {
        return super.transfer(to, amount);
    }

    /**
     * @dev Airdrops tokens to multiple students based on their tier.
     * @param recipients List of student addresses.
     * @param baseAmount Base amount before tier multiplier.
     */
    function airdropStudents(address[] calldata recipients, uint256 baseAmount) external onlyAdmin {
        for (uint256 i = 0; i < recipients.length; i++) {
            address student = recipients[i];
            if (students[student].active) {
                uint256 multiplier = _tierMultiplier(students[student].tier);
                uint256 amount = baseAmount * multiplier / 10; // scaled
                _mint(student, amount);
                emit AirdropExecuted(student, amount);
            }
        }
    }

    /**
     * @dev Returns tier multiplier.
     * @param tier Student tier.
     */
    function _tierMultiplier(StudentTier tier) internal pure returns (uint256) {
        if (tier == StudentTier.Gold) {
            return 30; // 3.0x
        } else if (tier == StudentTier.Silver) {
            return 20; // 2.0x
        } else {
            return 10; // 1.0x
        }
    }

    // === STUDENT MANAGEMENT ===

    /**
     * @dev Adds a new student to the system.
     * @param student Address of the student.
     */
    function addStudent(address student) external onlyAdmin {
        students[student] = Student({
            active: true,
            totalSpent: 0,
            tier: StudentTier.Bronze
        });
        emit StudentAdded(student);
    }

    /**
     * @dev Marks a student as inactive.
     * @param student Address of the student.
     */
    function removeStudent(address student) external onlyAdmin {
        students[student].active = false;
        emit StudentRemoved(student);
    }

    // === SERVICE PROVIDER MANAGEMENT ===

    /**
     * @dev Adds a new service provider.
     * @param provider Address of the provider.
     * @param name Name of the provider.
     * @param category Service category.
     */
    function addServiceProvider(address provider, string calldata name, string calldata category) external onlyAdmin {
        serviceProviders[provider] = ServiceProvider(name, category, true);
        emit ServiceProviderAdded(provider, name, category);
    }

    /**
     * @dev Marks a service provider as inactive.
     * @param provider Address of the provider.
     */
    function removeServiceProvider(address provider) external onlyAdmin {
        serviceProviders[provider].active = false;
        emit ServiceProviderRemoved(provider);
    }

    /**
     * @dev Updates service provider details.
     * @param provider Address of the provider.
     * @param newName New name for the provider.
     * @param newCategory New category.
     * @param active New active status.
     */
    function updateServiceProvider(address provider, string calldata newName, string calldata newCategory, bool active) external onlyAdmin {
        require(bytes(serviceProviders[provider].name).length > 0, "Provider not found");
        serviceProviders[provider] = ServiceProvider(newName, newCategory, active);
        emit ServiceProviderUpdated(provider, newName, newCategory, active);
    }

    // === FEE MANAGEMENT ===

    /**
     * @dev Updates the fee percentage.
     * @param newFeePercentage New fee in basis points.
     */
    function setFeePercentage(uint256 newFeePercentage) external onlyAdmin {
        require(newFeePercentage <= 1000, "Fee too high"); // Max 10%
        feePercentage = newFeePercentage;
        emit FeePercentageUpdated(newFeePercentage);
    }

    // === SERVICE MANAGEMENT ===

    /**
     * @dev Adds a service offered by the calling provider.
     * @param serviceId Unique service identifier.
     * @param name Name of the service.
     * @param price Price of the service.
     */
     function addService(uint256 serviceId, string calldata name, uint256 price) external onlyActiveProvider {
        services[msg.sender][serviceId] = Service(name, price, 0, true);
    }
 
   /**
     * @dev Marks a service as inactive.
     * @param serviceId Unique service identifier.
     */
    function removeService(uint256 serviceId) external onlyActiveProvider {
        services[msg.sender][serviceId].active = false;
    }

    /**
     * @dev Updates a service's details.
     * @param serviceId Unique service identifier.
     * @param newName New name of the service.
     * @param newPrice New price of the service.
     * @param active New active status.
     */
    function updateService(uint256 serviceId, string calldata newName, uint256 newPrice, bool active) external onlyActiveProvider {
        Service storage s = services[msg.sender][serviceId];
        require(bytes(s.name).length > 0, "Service doesn't exist");
        s.name = newName;
        s.price = newPrice;
        s.active = active;
    } 
   

    /**
     * @dev Sets a discount on a service.
     * @param serviceId Unique service identifier.
     * @param discount Discount percentage (0-100).
     */
    function setServiceDiscount(uint256 serviceId, uint256 discount) external onlyActiveProvider {
        require(discount <= 100, "Invalid discount");
        services[msg.sender][serviceId].discount = discount;
    }

    // === PAY FOR SPECIFIC SERVICE ===

    /**
     * @dev Allows a student to pay for a service.
     * @param provider Address of the service provider.
     * @param serviceId Unique service identifier.
     */
    function payForService(address provider, uint256 serviceId) external onlyActiveStudent(msg.sender) {
        require(serviceProviders[provider].active, "Inactive provider");
        Service memory s = services[provider][serviceId];
        require(s.active, "Service not available");

        uint256 discountedPrice = s.price - (s.price * s.discount / 100);
        uint256 fee = discountedPrice / 100;
        uint256 amountAfterFee = discountedPrice - fee;

        _transfer(msg.sender, university, fee);
        _transfer(msg.sender, provider, amountAfterFee);

        students[msg.sender].totalSpent += discountedPrice;
        _updateStudentTier(msg.sender);

        emit ServicePaid(msg.sender, provider, amountAfterFee, fee, serviceId);
    }

    // === INTERNAL TIER MANAGEMENT ===

    /**
     * @dev Updates a student's tier based on total spending.
     * @param student Address of the student.
     */
    function _updateStudentTier(address student) internal {
        Student storage s = students[student];

        StudentTier currentTier = s.tier;
        StudentTier newTier;

        if (s.totalSpent >= 5_000 * 10 ** decimals()) {
            newTier = StudentTier.Gold;
        } 
        else if (s.totalSpent >= 2_500 * 10 ** decimals()) {
            newTier = StudentTier.Silver;
        } else {
            newTier = StudentTier.Bronze;
        }

        if (newTier != currentTier) {
            s.tier = newTier;
            emit StudentTierUpdated(student, newTier);
        }
    }
}
