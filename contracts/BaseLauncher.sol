// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LaunchToken.sol";
import "./BondingCurve.sol";

/**
 * @title BaseLauncher
 * @notice Factory contract for launching tokens with bonding curves
 * @dev Main entry point for creating pump.fun style token launches
 */
contract BaseLauncher {

    // Platform fee collector
    address public feeCollector;

    // Owner of the factory
    address public owner;

    // Total supply for each token launch
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens

    // Tokens allocated to bonding curve
    uint256 public constant CURVE_SUPPLY = 800_000_000 * 10**18; // 80% to curve

    // Tokens allocated to creator
    uint256 public constant CREATOR_SUPPLY = 200_000_000 * 10**18; // 20% to creator

    // Launch fee (0.0001 ETH)
    uint256 public launchFee = 0.0001 ether;

    // Track all launched tokens
    address[] public allTokens;
    mapping(address => address) public tokenToCurve; // token => bonding curve
    mapping(address => TokenInfo) public tokenInfo;

    struct TokenInfo {
        string name;
        string symbol;
        address creator;
        address bondingCurve;
        uint256 createdAt;
        bool exists;
    }

    event TokenLaunched(
        address indexed token,
        address indexed curve,
        address indexed creator,
        string name,
        string symbol
    );

    event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector);
    event LaunchFeeUpdated(uint256 oldFee, uint256 newFee);

    constructor(address _feeCollector) {
        require(_feeCollector != address(0), "Invalid fee collector");
        owner = msg.sender;
        feeCollector = _feeCollector;
    }

    /**
     * @notice Launch a new token with bonding curve
     * @param name Token name
     * @param symbol Token symbol
     * @param metadata Optional metadata (could be IPFS hash)
     */
    function launchToken(
        string memory name,
        string memory symbol,
        string memory metadata
    ) external payable returns (address tokenAddress, address curveAddress) {
        require(msg.value >= launchFee, "Insufficient launch fee");
        require(bytes(name).length > 0, "Name required");
        require(bytes(symbol).length > 0, "Symbol required");

        // Deploy new token
        LaunchToken token = new LaunchToken();
        tokenAddress = address(token);

        // Deploy new bonding curve
        BondingCurve curve = new BondingCurve();
        curveAddress = address(curve);

        // Initialize token with total supply sent to this contract temporarily
        token.initialize(name, symbol, TOTAL_SUPPLY, address(this));

        // Transfer creator allocation
        require(token.transfer(msg.sender, CREATOR_SUPPLY), "Creator transfer failed");

        // Transfer curve allocation
        require(token.transfer(curveAddress, CURVE_SUPPLY), "Curve transfer failed");

        // Initialize bonding curve
        curve.initialize(tokenAddress, msg.sender, feeCollector, CURVE_SUPPLY);

        // Store token info
        allTokens.push(tokenAddress);
        tokenToCurve[tokenAddress] = curveAddress;
        tokenInfo[tokenAddress] = TokenInfo({
            name: name,
            symbol: symbol,
            creator: msg.sender,
            bondingCurve: curveAddress,
            createdAt: block.timestamp,
            exists: true
        });

        // Transfer launch fee to collector
        if (msg.value > 0) {
            payable(feeCollector).transfer(msg.value);
        }

        emit TokenLaunched(tokenAddress, curveAddress, msg.sender, name, symbol);

        return (tokenAddress, curveAddress);
    }

    /**
     * @notice Get total number of launched tokens
     */
    function getTokenCount() external view returns (uint256) {
        return allTokens.length;
    }

    /**
     * @notice Get token info by address
     */
    function getTokenInfo(address tokenAddress) external view returns (
        string memory name,
        string memory symbol,
        address creator,
        address bondingCurve,
        uint256 createdAt
    ) {
        TokenInfo memory info = tokenInfo[tokenAddress];
        require(info.exists, "Token not found");
        return (info.name, info.symbol, info.creator, info.bondingCurve, info.createdAt);
    }

    /**
     * @notice Get all launched tokens
     */
    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }

    /**
     * @notice Update fee collector (only owner)
     */
    function setFeeCollector(address newCollector) external {
        require(msg.sender == owner, "Only owner");
        require(newCollector != address(0), "Invalid address");

        address oldCollector = feeCollector;
        feeCollector = newCollector;

        emit FeeCollectorUpdated(oldCollector, newCollector);
    }

    /**
     * @notice Update launch fee (only owner)
     */
    function setLaunchFee(uint256 newFee) external {
        require(msg.sender == owner, "Only owner");

        uint256 oldFee = launchFee;
        launchFee = newFee;

        emit LaunchFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Transfer ownership (only owner)
     */
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner");
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}
