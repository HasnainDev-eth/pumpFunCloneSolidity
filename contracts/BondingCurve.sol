// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LaunchToken.sol";

/**
 * @title BondingCurve
 * @notice Implements a constant product bonding curve for token trading
 * @dev Uses x * y = k formula for price discovery before DEX listing
 */
contract BondingCurve {

    // Token being traded
    LaunchToken public token;

    // Target ETH to raise before graduation to DEX
    uint256 public constant GRADUATION_THRESHOLD = 24 ether;

    // Virtual liquidity for initial price stability
    uint256 public constant VIRTUAL_ETH = 1 ether;
    uint256 public constant VIRTUAL_TOKENS = 1_073_000_000 * 10**18; // ~1.073B tokens

    // Actual reserves
    uint256 public ethReserve;
    uint256 public tokenReserve;

    // Creator of this bonding curve
    address public creator;

    // Fee configuration (1% = 100 basis points)
    uint256 public constant FEE_BPS = 100; // 1%
    uint256 public constant BPS_DIVISOR = 10000;

    // Track if graduated to DEX
    bool public graduated;

    // Platform fee collector
    address public feeCollector;

    event TokensPurchased(address indexed buyer, uint256 ethIn, uint256 tokensOut);
    event TokensSold(address indexed seller, uint256 tokensIn, uint256 ethOut);
    event Graduated(uint256 finalEthRaised, uint256 finalTokensSold);

    /**
     * @notice Initialize a new bonding curve for a token
     * @param _token The token contract address
     * @param _creator Address of the token creator
     * @param _feeCollector Address to collect platform fees
     * @param _initialTokens Amount of tokens to seed the curve with
     */
    function initialize(
        address _token,
        address _creator,
        address _feeCollector,
        uint256 _initialTokens
    ) external {
        require(address(token) == address(0), "Already initialized");
        require(_token != address(0), "Invalid token");

        token = LaunchToken(_token);
        creator = _creator;
        feeCollector = _feeCollector;
        tokenReserve = _initialTokens;
    }

    /**
     * @notice Buy tokens with ETH
     * @dev Uses constant product formula with virtual liquidity
     * @param minTokensOut Minimum tokens expected (slippage protection)
     */
    function buy(uint256 minTokensOut) external payable {
        require(!graduated, "Already graduated");
        require(msg.value > 0, "Must send ETH");

        // Calculate fee
        uint256 fee = (msg.value * FEE_BPS) / BPS_DIVISOR;
        uint256 ethForPurchase = msg.value - fee;

        // Calculate tokens out using constant product formula
        // (ethReserve + VIRTUAL_ETH) * (tokenReserve + VIRTUAL_TOKENS) = k
        uint256 tokensOut = getTokensOut(ethForPurchase);
        require(tokensOut >= minTokensOut, "Slippage too high");
        require(tokensOut <= tokenReserve, "Insufficient token reserve");

        // Update reserves
        ethReserve += ethForPurchase;
        tokenReserve -= tokensOut;

        // Transfer tokens to buyer
        require(token.transfer(msg.sender, tokensOut), "Transfer failed");

        // Send fee to collector
        if (fee > 0) {
            payable(feeCollector).transfer(fee);
        }

        emit TokensPurchased(msg.sender, msg.value, tokensOut);

        // Check if we hit graduation threshold
        if (ethReserve >= GRADUATION_THRESHOLD) {
            _graduate();
        }
    }

    /**
     * @notice Sell tokens for ETH
     * @param tokenAmount Amount of tokens to sell
     * @param minEthOut Minimum ETH expected (slippage protection)
     */
    function sell(uint256 tokenAmount, uint256 minEthOut) external {
        require(!graduated, "Already graduated");
        require(tokenAmount > 0, "Must sell tokens");

        // Calculate ETH out using constant product formula
        uint256 ethOut = getEthOut(tokenAmount);
        require(ethOut >= minEthOut, "Slippage too high");
        require(ethOut <= ethReserve, "Insufficient ETH reserve");

        // Calculate fee
        uint256 fee = (ethOut * FEE_BPS) / BPS_DIVISOR;
        uint256 ethToSeller = ethOut - fee;

        // Update reserves
        tokenReserve += tokenAmount;
        ethReserve -= ethOut;

        // Transfer tokens from seller
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Transfer failed");

        // Send ETH to seller
        payable(msg.sender).transfer(ethToSeller);

        // Send fee to collector
        if (fee > 0) {
            payable(feeCollector).transfer(fee);
        }

        emit TokensSold(msg.sender, tokenAmount, ethToSeller);
    }

    /**
     * @notice Calculate tokens received for a given ETH amount
     * @param ethAmount Amount of ETH to spend
     * @return tokensOut Amount of tokens that will be received
     */
    function getTokensOut(uint256 ethAmount) public view returns (uint256 tokensOut) {
        // k = (ethReserve + VIRTUAL_ETH) * (tokenReserve + VIRTUAL_TOKENS)
        uint256 virtualEthReserve = ethReserve + VIRTUAL_ETH;
        uint256 virtualTokenReserve = tokenReserve + VIRTUAL_TOKENS;

        uint256 k = virtualEthReserve * virtualTokenReserve;
        uint256 newVirtualEthReserve = virtualEthReserve + ethAmount;
        uint256 newVirtualTokenReserve = k / newVirtualEthReserve;

        tokensOut = virtualTokenReserve - newVirtualTokenReserve;
    }

    /**
     * @notice Calculate ETH received for a given token amount
     * @param tokenAmount Amount of tokens to sell
     * @return ethOut Amount of ETH that will be received
     */
    function getEthOut(uint256 tokenAmount) public view returns (uint256 ethOut) {
        // k = (ethReserve + VIRTUAL_ETH) * (tokenReserve + VIRTUAL_TOKENS)
        uint256 virtualEthReserve = ethReserve + VIRTUAL_ETH;
        uint256 virtualTokenReserve = tokenReserve + VIRTUAL_TOKENS;

        uint256 k = virtualEthReserve * virtualTokenReserve;
        uint256 newVirtualTokenReserve = virtualTokenReserve + tokenAmount;
        uint256 newVirtualEthReserve = k / newVirtualTokenReserve;

        ethOut = virtualEthReserve - newVirtualEthReserve;
    }

    /**
     * @notice Get current price (ETH per token)
     */
    function getCurrentPrice() external view returns (uint256) {
        uint256 virtualEthReserve = ethReserve + VIRTUAL_ETH;
        uint256 virtualTokenReserve = tokenReserve + VIRTUAL_TOKENS;

        // Price = ETH reserve / Token reserve
        return (virtualEthReserve * 10**18) / virtualTokenReserve;
    }

    /**
     * @notice Mark curve as graduated and stop trading
     * @dev Called when ETH raised reaches threshold
     */
    function _graduate() internal {
        graduated = true;
        emit Graduated(ethReserve, VIRTUAL_TOKENS + VIRTUAL_TOKENS - tokenReserve);
    }

    /**
     * @notice Allow factory/owner to withdraw liquidity after graduation
     * @dev This would be used to create DEX liquidity
     */
    function withdrawLiquidity() external returns (uint256 ethAmount, uint256 tokenAmount) {
        require(graduated, "Not graduated yet");
        require(msg.sender == creator || msg.sender == feeCollector, "Not authorized");

        ethAmount = address(this).balance;
        tokenAmount = token.balanceOf(address(this));

        if (ethAmount > 0) {
            payable(msg.sender).transfer(ethAmount);
        }
        if (tokenAmount > 0) {
            token.transfer(msg.sender, tokenAmount);
        }
    }
}
