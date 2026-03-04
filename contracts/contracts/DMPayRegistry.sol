// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IENSRegistry {
    function setSubnodeOwner(bytes32 node, bytes32 label, address owner) external returns (bytes32);
    function setSubnodeRecord(bytes32 node, bytes32 label, address owner, address resolver, uint64 ttl) external;
    function owner(bytes32 node) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function setOwner(bytes32 node, address owner) external;
}

interface IENSResolver {
    function setContenthash(bytes32 node, bytes memory hash) external;
    function setAddr(bytes32 node, address addr) external;
}

contract DMPayRegistry is Ownable, ReentrancyGuard {

    bytes32 public parentNode;
    IENSRegistry public ensRegistry;
    IENSResolver public ensResolver;

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

    mapping(string => UserProfile) public profiles;
    mapping(address => string) public walletToHandle;

    event ProfileRegistered(address indexed wallet, string xHandle, uint256 priceUSDC);
    event ProfileUpdated(address indexed wallet, string xHandle, string bio, string pfpUrl, uint256 priceUSDC);
    event IPFSHashUpdated(address indexed wallet, string xHandle, string ipfsHash);
    event SubdomainRegistered(address indexed wallet, string xHandle, bytes32 ensNode);

    constructor(
        bytes32 _parentNode,
        address _ensRegistry,
        address _ensResolver
    ) Ownable(msg.sender) {
        parentNode = _parentNode;
        ensRegistry = IENSRegistry(_ensRegistry);
        ensResolver = IENSResolver(_ensResolver);
    }

    function toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    function getSubnode(string memory handle) public view returns (bytes32) {
        bytes32 label = keccak256(bytes(toLower(handle)));
        return keccak256(abi.encodePacked(parentNode, label));
    }

    function registerProfile(
        string calldata xHandle,
        string calldata bio,
        string calldata pfpUrl,
        uint256 priceUSDC
    ) external nonReentrant {
        require(bytes(xHandle).length > 0, "Handle required");
        require(priceUSDC > 0, "Price must be > 0");

        string memory handle = toLower(xHandle);
        require(!profiles[handle].registered, "Handle already registered");
        require(bytes(walletToHandle[msg.sender]).length == 0, "Wallet already registered");

        profiles[handle] = UserProfile({
            wallet: msg.sender,
            xHandle: xHandle,
            bio: bio,
            pfpUrl: pfpUrl,
            priceUSDC: priceUSDC,
            ipfsHash: "",
            registered: true,
            active: true
        });

        walletToHandle[msg.sender] = handle;
        emit ProfileRegistered(msg.sender, xHandle, priceUSDC);
        _tryRegisterSubdomain(handle, msg.sender);
    }

    function _tryRegisterSubdomain(string memory handle, address userWallet) internal {
        bytes32 label = keccak256(bytes(handle));
        bytes32 subnode = keccak256(abi.encodePacked(parentNode, label));

        try ensRegistry.setSubnodeRecord(
            parentNode,
            label,
            address(this),
            address(ensResolver),
            0
        ) {
            try ensResolver.setAddr(subnode, userWallet) {} catch {}
            try ensRegistry.setOwner(subnode, userWallet) {} catch {}
            emit SubdomainRegistered(userWallet, handle, subnode);
        } catch {
            try ensRegistry.setSubnodeOwner(parentNode, label, userWallet) returns (bytes32 node) {
                emit SubdomainRegistered(userWallet, handle, node);
            } catch {}
        }
    }

    // Frontend passes pre-encoded contenthash bytes
    function updateIPFSHash(string calldata ipfsHash, bytes calldata contenthash) external {
        string memory handle = walletToHandle[msg.sender];
        require(bytes(handle).length > 0, "Not registered");
        profiles[handle].ipfsHash = ipfsHash;

        bytes32 label = keccak256(bytes(handle));
        bytes32 subnode = keccak256(abi.encodePacked(parentNode, label));

        try ensRegistry.setSubnodeRecord(
            parentNode,
            label,
            address(this),
            address(ensResolver),
            0
        ) {
            if (contenthash.length > 0) {
                try ensResolver.setContenthash(subnode, contenthash) {} catch {}
            }
            try ensResolver.setAddr(subnode, msg.sender) {} catch {}
            try ensRegistry.setOwner(subnode, msg.sender) {} catch {}
        } catch {}

        emit IPFSHashUpdated(msg.sender, handle, ipfsHash);
    }

    function updateProfile(
        string calldata bio,
        string calldata pfpUrl,
        uint256 priceUSDC
    ) external {
        string memory handle = walletToHandle[msg.sender];
        require(bytes(handle).length > 0, "Not registered");
        require(priceUSDC > 0, "Price must be > 0");

        profiles[handle].bio = bio;
        profiles[handle].pfpUrl = pfpUrl;
        profiles[handle].priceUSDC = priceUSDC;

        emit ProfileUpdated(msg.sender, handle, bio, pfpUrl, priceUSDC);
    }

    function registerSubdomain() external {
        string memory handle = walletToHandle[msg.sender];
        require(bytes(handle).length > 0, "Not registered");

        bytes32 label = keccak256(bytes(handle));
        bytes32 subnode = keccak256(abi.encodePacked(parentNode, label));

        ensRegistry.setSubnodeRecord(parentNode, label, address(this), address(ensResolver), 0);
        ensResolver.setAddr(subnode, msg.sender);
        ensRegistry.setOwner(subnode, msg.sender);

        emit SubdomainRegistered(msg.sender, handle, subnode);
    }

    function getProfile(string calldata xHandle) external view returns (UserProfile memory) {
        return profiles[toLower(xHandle)];
    }

    function getProfileByWallet(address wallet) external view returns (UserProfile memory) {
        string memory handle = walletToHandle[wallet];
        return profiles[handle];
    }

    function setParentNode(bytes32 _parentNode) external onlyOwner {
        parentNode = _parentNode;
    }

    function setENSRegistry(address _ensRegistry) external onlyOwner {
        ensRegistry = IENSRegistry(_ensRegistry);
    }

    function setENSResolver(address _ensResolver) external onlyOwner {
        ensResolver = IENSResolver(_ensResolver);
    }
}
