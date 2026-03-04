// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IDMPayRegistry {
    struct UserProfile {
        address wallet;
        string xHandle;
        string bio;
        string pfpUrl;
        uint256 priceUSDC;
        string ipfsHash;
        bool registered;
        bool active;
    }
    function getProfileByWallet(address wallet) external view returns (UserProfile memory);
    function getProfile(string calldata xHandle) external view returns (UserProfile memory);
}

contract DMPayMessaging is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public usdc;
    IDMPayRegistry public registry;

    // 2.5% fee = 250 basis points
    uint256 public constant FEE_BPS = 250;
    uint256 public constant BPS_BASE = 10000;

    enum ConversationStatus { Closed, Open }

    struct Conversation {
        address sender;
        address recipient;
        uint256 totalPaid;
        uint256 lastPayment;
        ConversationStatus status;
        uint256 openedAt;
        uint256 closedAt;
        uint256 messageCount;
    }

    // conversationId => Conversation
    mapping(bytes32 => Conversation) public conversations;
    // sender => recipient => conversationId
    mapping(address => mapping(address => bytes32)) public activeConversation;

    // accumulated fees for owner to withdraw
    uint256 public accumulatedFees;

    event ConversationOpened(
        bytes32 indexed conversationId,
        address indexed sender,
        address indexed recipient,
        uint256 amountPaid,
        uint256 fee
    );

    event MessagePaid(
        bytes32 indexed conversationId,
        address indexed sender,
        address indexed recipient,
        uint256 amountPaid,
        uint256 fee
    );

    event ConversationClosed(
        bytes32 indexed conversationId,
        address indexed closedBy,
        address indexed recipient
    );

    constructor(address _usdc, address _registry) Ownable(msg.sender) {
        usdc = IERC20(_usdc);
        registry = IDMPayRegistry(_registry);
    }

    function getConversationId(address sender, address recipient) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(sender, recipient));
    }

    function calculateFee(uint256 amount) public pure returns (uint256 fee, uint256 net) {
        fee = (amount * FEE_BPS) / BPS_BASE;
        net = amount - fee;
    }

    function openConversation(address recipient) external nonReentrant {
        require(recipient != msg.sender, "Cannot message yourself");

        // Get recipient price from registry
        IDMPayRegistry.UserProfile memory profile = registry.getProfileByWallet(recipient);
        require(profile.registered, "Recipient not registered");
        require(profile.active, "Recipient not active");
        require(profile.priceUSDC > 0, "Recipient has no price set");

        bytes32 convId = getConversationId(msg.sender, recipient);
        Conversation storage conv = conversations[convId];

        require(conv.status == ConversationStatus.Closed, "Conversation already open");

        uint256 price = profile.priceUSDC;
        (uint256 fee, uint256 net) = calculateFee(price);

        // Transfer USDC from sender
        usdc.safeTransferFrom(msg.sender, address(this), price);

        // Pay recipient net amount
        usdc.safeTransfer(recipient, net);

        // Accumulate fee
        accumulatedFees += fee;

        // Update conversation
        conv.sender = msg.sender;
        conv.recipient = recipient;
        conv.totalPaid += price;
        conv.lastPayment = block.timestamp;
        conv.status = ConversationStatus.Open;
        conv.openedAt = block.timestamp;
        conv.messageCount += 1;

        activeConversation[msg.sender][recipient] = convId;

        emit ConversationOpened(convId, msg.sender, recipient, price, fee);
    }

    function payForMessage(address recipient) external nonReentrant {
        bytes32 convId = getConversationId(msg.sender, recipient);
        Conversation storage conv = conversations[convId];

        require(conv.status == ConversationStatus.Open, "Conversation not open");
        require(conv.sender == msg.sender, "Not conversation sender");

        IDMPayRegistry.UserProfile memory profile = registry.getProfileByWallet(recipient);
        require(profile.registered, "Recipient not registered");

        uint256 price = profile.priceUSDC;
        (uint256 fee, uint256 net) = calculateFee(price);

        usdc.safeTransferFrom(msg.sender, address(this), price);
        usdc.safeTransfer(recipient, net);
        accumulatedFees += fee;

        conv.totalPaid += price;
        conv.lastPayment = block.timestamp;
        conv.messageCount += 1;

        emit MessagePaid(convId, msg.sender, recipient, price, fee);
    }

    function closeConversation(address sender) external nonReentrant {
        bytes32 convId = getConversationId(sender, msg.sender);
        Conversation storage conv = conversations[convId];

        require(conv.status == ConversationStatus.Open, "Conversation not open");
        require(conv.recipient == msg.sender, "Only recipient can close");

        conv.status = ConversationStatus.Closed;
        conv.closedAt = block.timestamp;

        emit ConversationClosed(convId, msg.sender, msg.sender);
    }

    function getConversation(address sender, address recipient)
        external
        view
        returns (Conversation memory)
    {
        bytes32 convId = getConversationId(sender, recipient);
        return conversations[convId];
    }

    function isConversationOpen(address sender, address recipient)
        external
        view
        returns (bool)
    {
        bytes32 convId = getConversationId(sender, recipient);
        return conversations[convId].status == ConversationStatus.Open;
    }

    // Owner withdraws accumulated fees
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = accumulatedFees;
        require(amount > 0, "No fees to withdraw");
        accumulatedFees = 0;
        usdc.safeTransfer(owner(), amount);
    }

    function setRegistry(address _registry) external onlyOwner {
        registry = IDMPayRegistry(_registry);
    }

    function setUSDC(address _usdc) external onlyOwner {
        usdc = IERC20(_usdc);
    }
}
