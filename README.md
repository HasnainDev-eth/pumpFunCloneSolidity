# BaseLauncher - Pump.Fun Clone on Solidity

A fair launch token platform with bonding curve mechanics, similar to pump.fun. Launch tokens with automatic price discovery and optional DEX graduation.

## Overview

BaseLauncher allows anyone to create and trade tokens through a bonding curve mechanism before they graduate to a DEX. The system ensures fair launches with no pre-mines and provides immediate liquidity through an automated market maker.

## Core Contracts

### 1. LaunchToken.sol
Simple ERC20 token with one-time mint capability. Prevents inflation after initial supply is minted.

**Key Features:**
- Standard ERC20 functionality
- One-time mint protection
- No owner controls after initialization

### 2. BondingCurve.sol
Implements constant product AMM for token trading before DEX listing.

**Key Features:**
- Constant product formula (x * y = k)
- Virtual liquidity for price stability
- 1% trading fee
- Automatic graduation at 24 ETH raised
- Slippage protection

**Parameters:**
- Graduation threshold: 24 ETH
- Virtual ETH reserve: 1 ETH
- Virtual token reserve: 1.073B tokens
- Trading fee: 1%

### 3. BaseLauncher.sol
Factory contract for creating new token launches.

**Key Features:**
- Deploy token + bonding curve pairs
- Track all launched tokens
- Configurable launch fees
- 80% tokens to curve, 20% to creator

**Token Distribution:**
- Total supply: 1 billion tokens
- Bonding curve: 800 million (80%)
- Creator: 200 million (20%)

### 4. LiquidityManager.sol
Manages DEX liquidity creation and locking after graduation.

**Key Features:**
- Create Uniswap V2 pools
- Optional 10-year liquidity locks
- Prevent rug pulls

## How It Works

### 1. Token Launch
Anyone can launch a token by calling `BaseLauncher.launchToken()`:
```solidity
function launchToken(
    string memory name,
    string memory symbol,
    string memory metadata
) external payable returns (address token, address curve)
```

- Pay 0.0001 ETH launch fee
- Receive 20% of token supply
- 80% allocated to bonding curve

### 2. Trading Phase
Users buy/sell tokens through the bonding curve:

**Buying:**
```solidity
function buy(uint256 minTokensOut) external payable
```

**Selling:**
```solidity
function sell(uint256 tokenAmount, uint256 minEthOut) external
```

Price is determined by constant product formula:
- `k = (ethReserve + virtualETH) * (tokenReserve + virtualTokens)`
- Virtual reserves ensure smooth price discovery from day one

### 3. Graduation
When bonding curve raises 24 ETH:
- Trading stops on bonding curve
- Creator can withdraw liquidity
- Create Uniswap V2 pool via LiquidityManager
- Optionally lock liquidity for 10 years

### 4. DEX Trading
After graduation, token trades on Uniswap V2 like any normal token.

## Usage Examples

### Launch a Token
```solidity
// Deploy factory
BaseLauncher launcher = new BaseLauncher(feeCollectorAddress);

// Launch token
(address token, address curve) = launcher.launchToken{value: 0.0001 ether}(
    "My Meme Coin",
    "MEME",
    "ipfs://metadata-hash"
);
```

### Buy Tokens
```solidity
BondingCurve curve = BondingCurve(curveAddress);

// Get quote
uint256 tokensOut = curve.getTokensOut(1 ether);

// Buy with 1% slippage tolerance
uint256 minTokens = tokensOut * 99 / 100;
curve.buy{value: 1 ether}(minTokens);
```

### Sell Tokens
```solidity
// Approve curve to spend tokens
token.approve(curveAddress, tokenAmount);

// Get quote
uint256 ethOut = curve.getEthOut(tokenAmount);

// Sell with 1% slippage tolerance
uint256 minEth = ethOut * 99 / 100;
curve.sell(tokenAmount, minEth);
```

### Create DEX Liquidity
```solidity
LiquidityManager manager = new LiquidityManager(uniswapRouterAddress);

// After graduation, withdraw from curve
(uint256 eth, uint256 tokens) = curve.withdrawLiquidity();

// Create and lock liquidity
token.approve(address(manager), tokens);
(address pair, uint256 lp) = manager.createLiquidity{value: eth}(
    address(token),
    tokens,
    true // lock for 10 years
);
```

## Bonding Curve Math

The bonding curve uses a constant product formula similar to Uniswap:

**Price Calculation:**
```
k = (ethReserve + virtualETH) * (tokenReserve + virtualTokens)

For buys:
newTokenReserve = k / (ethReserve + ethIn)
tokensOut = tokenReserve - newTokenReserve

For sells:
newEthReserve = k / (tokenReserve + tokensIn)
ethOut = ethReserve - newEthReserve
```

**Virtual Reserves:**
Virtual reserves ensure there's always liquidity and prevent extreme price movements:
- Virtual ETH: 1 ETH
- Virtual Tokens: 1.073B tokens

This gives an initial price and ensures the curve is never empty.

## Security Features

1. **One-time Mint:** Tokens can only be minted once during initialization
2. **Slippage Protection:** Min/max amount parameters on trades
3. **Liquidity Locks:** Optional 10-year locks prevent rug pulls
4. **No Admin Controls:** Tokens have no owner after launch
5. **Graduation Threshold:** Automatic migration ensures fair price discovery

## Deployment

### Prerequisites
- Solidity ^0.8.20
- Uniswap V2 Router address for your network

### Deploy Order
1. Deploy `BaseLauncher` with fee collector address
2. Deploy `LiquidityManager` with Uniswap router address
3. Users can now launch tokens via BaseLauncher

### Network Addresses
**Uniswap V2 Router:**
- Ethereum Mainnet: `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`
- Base: `0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24`
- Arbitrum: `0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24`

## License

MIT

## Inspiration

This project is inspired by:
- [pump.fun](https://pump.fun) - The original Solana token launcher
- [memex-contracts](https://github.com/scriptoshi/memex-contracts) - Reference implementation
