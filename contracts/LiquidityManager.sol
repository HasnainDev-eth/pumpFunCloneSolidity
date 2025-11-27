// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LaunchToken.sol";
import "./interfaces/IUniswapV2.sol";

/**
 * @title LiquidityManager
 * @notice Manages DEX liquidity creation after bonding curve graduation
 * @dev Creates and optionally locks Uniswap V2 liquidity pools
 */
contract LiquidityManager {

    // Uniswap V2 Router address (mainnet: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)
    IUniswapV2Router public router;

    // Lock duration for LP tokens (10 years)
    uint256 public constant LOCK_DURATION = 10 * 365 days;

    struct LiquidityLock {
        address token;
        address pair;
        uint256 liquidity;
        uint256 unlockTime;
        address owner;
        bool withdrawn;
    }

    // Track locked liquidity
    mapping(uint256 => LiquidityLock) public locks;
    uint256 public lockCount;

    event LiquidityAdded(
        address indexed token,
        address indexed pair,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event LiquidityLocked(
        uint256 indexed lockId,
        address indexed token,
        address indexed pair,
        uint256 liquidity,
        uint256 unlockTime
    );

    event LiquidityWithdrawn(uint256 indexed lockId, address indexed owner, uint256 liquidity);

    constructor(address _router) {
        require(_router != address(0), "Invalid router");
        router = IUniswapV2Router(_router);
    }

    /**
     * @notice Create Uniswap V2 liquidity pool
     * @param token Token address
     * @param tokenAmount Amount of tokens to add
     * @param lockLiquidity Whether to lock the LP tokens
     */
    function createLiquidity(
        address token,
        uint256 tokenAmount,
        bool lockLiquidity
    ) external payable returns (address pair, uint256 liquidity) {
        require(msg.value > 0, "Must send ETH");
        require(tokenAmount > 0, "Must provide tokens");

        // Transfer tokens from sender
        LaunchToken tokenContract = LaunchToken(token);
        require(
            tokenContract.transferFrom(msg.sender, address(this), tokenAmount),
            "Token transfer failed"
        );

        // Approve router to spend tokens
        tokenContract.approve(address(router), tokenAmount);

        // Add liquidity to Uniswap V2
        (uint256 amountToken, uint256 amountETH, uint256 lp) = router.addLiquidityETH{value: msg.value}(
            token,
            tokenAmount,
            0, // Accept any amount of tokens
            0, // Accept any amount of ETH
            lockLiquidity ? address(this) : msg.sender, // LP tokens go to this contract if locking
            block.timestamp + 15 minutes
        );

        // Get pair address
        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
        pair = factory.getPair(token, router.WETH());
        liquidity = lp;

        emit LiquidityAdded(token, pair, amountToken, amountETH, liquidity);

        // Lock liquidity if requested
        if (lockLiquidity) {
            uint256 unlockTime = block.timestamp + LOCK_DURATION;

            locks[lockCount] = LiquidityLock({
                token: token,
                pair: pair,
                liquidity: liquidity,
                unlockTime: unlockTime,
                owner: msg.sender,
                withdrawn: false
            });

            emit LiquidityLocked(lockCount, token, pair, liquidity, unlockTime);
            lockCount++;
        }

        // Refund excess ETH if any
        if (msg.value > amountETH) {
            payable(msg.sender).transfer(msg.value - amountETH);
        }

        return (pair, liquidity);
    }

    /**
     * @notice Withdraw locked liquidity after unlock time
     * @param lockId ID of the liquidity lock
     */
    function withdrawLiquidity(uint256 lockId) external {
        LiquidityLock storage lock = locks[lockId];

        require(lock.liquidity > 0, "Lock does not exist");
        require(!lock.withdrawn, "Already withdrawn");
        require(msg.sender == lock.owner, "Not lock owner");
        require(block.timestamp >= lock.unlockTime, "Still locked");

        lock.withdrawn = true;

        // Transfer LP tokens to owner
        IUniswapV2Pair(lock.pair).transfer(lock.owner, lock.liquidity);

        emit LiquidityWithdrawn(lockId, lock.owner, lock.liquidity);
    }

    /**
     * @notice Get lock info
     */
    function getLockInfo(uint256 lockId) external view returns (
        address token,
        address pair,
        uint256 liquidity,
        uint256 unlockTime,
        address owner,
        bool withdrawn
    ) {
        LiquidityLock memory lock = locks[lockId];
        return (lock.token, lock.pair, lock.liquidity, lock.unlockTime, lock.owner, lock.withdrawn);
    }

    /**
     * @notice Get time remaining until unlock
     */
    function getTimeUntilUnlock(uint256 lockId) external view returns (uint256) {
        LiquidityLock memory lock = locks[lockId];
        if (block.timestamp >= lock.unlockTime) {
            return 0;
        }
        return lock.unlockTime - block.timestamp;
    }
}
