// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../@openzeppelin/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract CampusCoin is ERC20 {

    // === STATE VARIABLES ===

    address public admin; // Address of the administrator (deployer)
    address public university; // Address representing the university (for fee collection)

    uint256 public constant UNIT = 10 ** 18; // Token unit, representing 1 CampusCoin

    uint256 public feePercentage; // Platform fee charged during service payments (in basis points)

    enum StudentTier { Bronze, Silver, Gold } // Different reward tiers for students

    struct Student {
        bool active; // Whether the student is currently registered
        uint256 totalSpent; // Total tokens spent by student
        StudentTier tier; // Current tier of the student
    }

    struct ServiceProvider {
        string name; // Name of the service provider
        string category; // Category of services offered
        bool active; // Whether provider is active
        uint256 totalRating; // Sum of all ratings received
        uint256 ratingCount; // Number of ratings received
    }

    struct Service {
        string name; // Name of the service
        uint256 price; // Price in tokens (scaled by UNIT)
        uint256 discount; // Discount in percentage (0-100)
        bool active; // Whether the service is active
    }

    mapping(address => Student) public students;
    mapping(address => ServiceProvider) public serviceProviders;
    mapping(address => mapping(uint256 => Service)) public services; // provider => (serviceId => Service)
    mapping(address => mapping(address => bool)) public hasRated; // student => provider => rated or not

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
    event ProviderRated(address indexed student, address indexed provider, uint8 rating);

    // === MODIFIERS ===

    /**
     * @dev Restricts function to admin only.
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    /**
     * @dev Restricts function to active service providers only.
     */
    modifier onlyActiveProvider() {
        require(serviceProviders[msg.sender].active, "Only active providers allowed");
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
        _mint(msg.sender, 3000 * UNIT); // Initial mint to admin
        feePercentage = 100; // Default 1% fee (100 basis points)
    }

    // === TOKEN MANAGEMENT ===

     /**
     * @dev Mints tokens to a student's account.
     * @param to Address to receive tokens.
     * @param amount Amount of tokens to mint.
     */
     function mint(address to, uint256 amount) public onlyAdmin onlyActiveStudent(to) {
        uint256 scaledAmount = amount * UNIT;
        _mint(to, scaledAmount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Burns tokens from the caller's account.
     * @param amount Amount of tokens to burn.
     */
    function burn(uint256 amount) public {
        uint256 scaledAmount = amount * UNIT;
        _burn(msg.sender, scaledAmount);
        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @dev Transfers tokens to another active student.
     * @param to Address of the recipient.
     * @param amount Amount of tokens to transfer.
     */
    function transfer(address to, uint256 amount) public override onlyActiveStudent(to) returns (bool) {
        uint256 scaledAmount = amount * UNIT;
        return super.transfer(to, scaledAmount);
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
        serviceProviders[provider] = ServiceProvider({
            name: name,
            category: category,
            active: true,
            totalRating: 0,
            ratingCount: 0
        });
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

        ServiceProvider storage sp = serviceProviders[provider];
        sp.name = newName;
        sp.category = newCategory;
        sp.active = active;

        emit ServiceProviderUpdated(provider, newName, newCategory, active);
    }


    // === SERVICE MANAGEMENT ===

    /**
     * @dev Adds a service offered by the calling provider.
     * @param serviceId Unique service identifier.
     * @param name Name of the service.
     * @param price Price of the service.
     */
    function addService(uint256 serviceId, string calldata name, uint256 price) external onlyActiveProvider {
        services[msg.sender][serviceId] = Service({
            name: name,
            price: price * UNIT,
            discount: 0,
            active: true
        });
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
        Service storage service = services[msg.sender][serviceId];

        require(bytes(service.name).length > 0, "Service does not exist");

        service.name = newName;
        service.price = newPrice * UNIT;
        service.active = active;
    }

    /**
     * @dev Sets a discount on a service.
     * @param serviceId Unique service identifier.
     * @param discount Discount percentage (0-100).
     */
    function setServiceDiscount(uint256 serviceId, uint256 discount) external onlyActiveProvider {
        require(discount <= 100, "Invalid discount percentage");
        services[msg.sender][serviceId].discount = discount;
    }

    // === FEE MANAGEMENT ===
    /**
     * @dev Updates the fee percentage.
     * @param newFeePercentage New fee in basis points.
     */
    function setFeePercentage(uint256 newFeePercentage) external onlyAdmin {
        require(newFeePercentage <= 1000, "Fee too high (max 10%)");
        feePercentage = newFeePercentage;
        emit FeePercentageUpdated(newFeePercentage);
    }

    // === AIRDROPS ===
    /**
     * @dev Airdrops tokens to multiple students based on their tier.
     * @param recipients List of student addresses.
     * @param baseAmount Base amount before tier multiplier.
     */
    function airdropStudents(address[] calldata recipients, uint256 baseAmount) external onlyAdmin {
        uint256 totalRecipients = recipients.length;

        for (uint256 i = 0; i < totalRecipients; i++) {
            address student = recipients[i];

            if (students[student].active) {
                uint256 multiplier = _tierMultiplier(students[student].tier);
                uint256 airdropAmount = baseAmount * multiplier;

                _mint(student, airdropAmount * UNIT);
                emit AirdropExecuted(student, airdropAmount);
            }
        }
    }

    // === SERVICE PAYMENT ===
    /**
     * @dev Allows a student to pay for a service.
     * @param provider Address of the service provider.
     * @param serviceId Unique service identifier.
     */
    function payForService(address provider, uint256 serviceId) external onlyActiveStudent(msg.sender) {
        require(serviceProviders[provider].active, "Service provider not active");

        Service memory service = services[provider][serviceId];
        require(service.active, "Service not available");

        uint256 discountedPrice = service.price - ((service.price * service.discount) / 100);
        uint256 fee = (discountedPrice * feePercentage) / 10000;
        uint256 amountToProvider = discountedPrice - fee;

        _transfer(msg.sender, university, fee);
        _transfer(msg.sender, provider, amountToProvider);

        students[msg.sender].totalSpent += discountedPrice;

        _updateStudentTier(msg.sender);

        emit ServicePaid(msg.sender, provider, amountToProvider / UNIT, fee / UNIT, serviceId);
    }


    // === PROVIDER REPUTATION SYSTEM ===

    /**
     * @dev Allows a student to rate a service provider (only once).
     * @param provider Address of the service provider.
     * @param rating Rating value between 1 and 5.
     */
    function rateProvider(address provider, uint8 rating) external onlyActiveStudent(msg.sender) {
        require(serviceProviders[provider].active, "Service provider not active");
        require(!hasRated[msg.sender][provider], "You have already rated this provider");
        require(rating >= 1 && rating <= 5, "Rating must be between 1 and 5");

        hasRated[msg.sender][provider] = true;
        serviceProviders[provider].totalRating += rating;
        serviceProviders[provider].ratingCount += 1;

        emit ProviderRated(msg.sender, provider, rating);
    }

    /**
     * @dev Returns the average rating and total number of ratings for a provider.
     * @param provider Address of the service provider.
     * @return averageRating Average rating value.
     * @return numberOfRatings Total number of ratings received.
     */
    function getProviderAverageRating(address provider) external view returns (uint256 averageRating, uint256 numberOfRatings) {
        ServiceProvider memory sp = serviceProviders[provider];
        if (sp.ratingCount == 0) {
            return (0, 0);
        }
        averageRating = sp.totalRating / sp.ratingCount;
        numberOfRatings = sp.ratingCount;
    }


    // === INTERNAL FUNCTIONS ===
    /**
     * @dev Returns tier multiplier.
     * @param tier Student tier.
     */
    function _tierMultiplier(StudentTier tier) internal pure returns (uint256) {
        if (tier == StudentTier.Gold) {
            return 30;
        } else if (tier == StudentTier.Silver) {
            return 20;
        } else {
            return 10;
        }
    }

    /**
     * @dev Updates a student's tier based on total spending.
     * @param student Address of the student.
     */
    function _updateStudentTier(address student) internal {
        Student storage s = students[student];

        StudentTier previousTier = s.tier;
        StudentTier newTier;

        uint256 silverThreshold = 2500 * UNIT;
        uint256 goldThreshold = 5000 * UNIT;

        if (s.totalSpent >= goldThreshold) {
            newTier = StudentTier.Gold;
        } else if (s.totalSpent >= silverThreshold) {
            newTier = StudentTier.Silver;
        } else {
            newTier = StudentTier.Bronze;
        }

        if (newTier != previousTier) {
            s.tier = newTier;
            emit StudentTierUpdated(student, newTier);
        }
    }
}