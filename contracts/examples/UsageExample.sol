// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BaseLauncher.sol";
import "../BondingCurve.sol";
import "../LaunchToken.sol";
import "../LiquidityManager.sol";

/**
 * @title UsageExample
 * @notice Example contract showing how to interact with BaseLauncher
 * @dev This demonstrates the full lifecycle from launch to DEX
 */
contract UsageExample {

    BaseLauncher public launcher;
    LiquidityManager public liquidityManager;

    constructor(address _launcher, address _liquidityManager) {
        launcher = BaseLauncher(_launcher);
        liquidityManager = LiquidityManager(_liquidityManager);
    }

    /**
     * @notice Example 1: Launch a new token
     */
    function exampleLaunchToken() external payable returns (address token, address curve) {
        // Launch token with 0.0001 ETH fee
        (token, curve) = launcher.launchToken{value: 0.0001 ether}(
            "My Awesome Token",
            "AWESOME",
            "ipfs://QmExample123" // metadata
        );

        // You now have 20% of the supply (200M tokens)
        // The bonding curve has 80% (800M tokens)
    }

    /**
     * @notice Example 2: Buy tokens from bonding curve
     */
    function exampleBuyTokens(address curveAddress) external payable {
        BondingCurve curve = BondingCurve(curveAddress);

        // Get quote for how many tokens you'll receive
        uint256 tokensOut = curve.getTokensOut(msg.value);

        // Set 1% slippage tolerance
        uint256 minTokensOut = tokensOut * 99 / 100;

        // Buy tokens
        curve.buy{value: msg.value}(minTokensOut);
    }

    /**
     * @notice Example 3: Sell tokens to bonding curve
     */
    function exampleSellTokens(address curveAddress, uint256 tokenAmount) external {
        BondingCurve curve = BondingCurve(curveAddress);
        LaunchToken token = LaunchToken(address(curve.token()));

        // Approve curve to spend your tokens
        token.approve(curveAddress, tokenAmount);

        // Get quote for how much ETH you'll receive
        uint256 ethOut = curve.getEthOut(tokenAmount);

        // Set 1% slippage tolerance
        uint256 minEthOut = ethOut * 99 / 100;

        // Sell tokens
        curve.sell(tokenAmount, minEthOut);
    }

    /**
     * @notice Example 4: Check if curve graduated
     */
    function exampleCheckGraduation(address curveAddress) external view returns (
        bool isGraduated,
        uint256 ethRaised,
        uint256 threshold
    ) {
        BondingCurve curve = BondingCurve(curveAddress);

        isGraduated = curve.graduated();
        ethRaised = curve.ethReserve();
        threshold = curve.GRADUATION_THRESHOLD();
    }

    /**
     * @notice Example 5: Create DEX liquidity after graduation
     */
    function exampleCreateDEXLiquidity(address curveAddress) external {
        BondingCurve curve = BondingCurve(curveAddress);
        LaunchToken token = LaunchToken(address(curve.token()));

        // Ensure curve has graduated
        require(curve.graduated(), "Not graduated yet");

        // Withdraw liquidity from curve
        (uint256 ethAmount, uint256 tokenAmount) = curve.withdrawLiquidity();

        // Approve liquidity manager to spend tokens
        token.approve(address(liquidityManager), tokenAmount);

        // Create Uniswap pool and lock liquidity for 10 years
        liquidityManager.createLiquidity{value: ethAmount}(
            address(token),
            tokenAmount,
            true // lock LP tokens
        );
    }

    /**
     * @notice Example 6: Get current token price
     */
    function exampleGetPrice(address curveAddress) external view returns (uint256 priceInWei) {
        BondingCurve curve = BondingCurve(curveAddress);

        // Returns price in wei per token (scaled by 10^18)
        priceInWei = curve.getCurrentPrice();

        // To get price per whole token: priceInWei / 10^18
        // To get tokens per ETH: 10^18 / priceInWei
    }

    /**
     * @notice Example 7: Get token info
     */
    function exampleGetTokenInfo(address tokenAddress) external view returns (
        string memory name,
        string memory symbol,
        address creator,
        address bondingCurve,
        uint256 createdAt
    ) {
        return launcher.getTokenInfo(tokenAddress);
    }

    /**
     * @notice Example 8: List all launched tokens
     */
    function exampleGetAllTokens() external view returns (address[] memory) {
        return launcher.getAllTokens();
    }

    /**
     * @notice Example 9: Calculate buy/sell preview
     */
    function exampleCalculateTradePreview(
        address curveAddress,
        uint256 ethAmount
    ) external view returns (
        uint256 buyTokensOut,
        uint256 buyPricePerToken,
        uint256 sellEthOut,
        uint256 sellPricePerToken
    ) {
        BondingCurve curve = BondingCurve(curveAddress);

        // If you buy with ethAmount, how many tokens do you get?
        buyTokensOut = curve.getTokensOut(ethAmount);
        buyPricePerToken = (ethAmount * 10**18) / buyTokensOut;

        // If you sell 1M tokens, how much ETH do you get?
        uint256 tokenSellAmount = 1_000_000 * 10**18;
        sellEthOut = curve.getEthOut(tokenSellAmount);
        sellPricePerToken = (sellEthOut * 10**18) / tokenSellAmount;
    }

    /**
     * @notice Example 10: Full lifecycle simulation
     */
    function exampleFullLifecycle() external payable {
        // 1. Launch token
        (address token, address curve) = launcher.launchToken{value: 0.0001 ether}(
            "Demo Token",
            "DEMO",
            ""
        );

        // 2. Buy some tokens to help it graduate
        // (In reality, multiple users would buy)
        BondingCurve bondingCurve = BondingCurve(curve);
        bondingCurve.buy{value: 25 ether}(0); // Buy enough to graduate

        // 3. Check if graduated
        require(bondingCurve.graduated(), "Should be graduated");

        // 4. Withdraw and create DEX liquidity
        (uint256 ethAmount, uint256 tokenAmount) = bondingCurve.withdrawLiquidity();

        LaunchToken(token).approve(address(liquidityManager), tokenAmount);
        liquidityManager.createLiquidity{value: ethAmount}(token, tokenAmount, true);

        // Done! Token is now trading on Uniswap with locked liquidity
    }

    // Allow contract to receive ETH
    receive() external payable {}
}
