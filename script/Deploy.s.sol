// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/BaseLauncher.sol";
import "../contracts/LiquidityManager.sol";

/**
 * @title DeployScript
 * @notice Deployment script for BaseLauncher platform
 * @dev Run with: forge script script/Deploy.s.sol --rpc-url <network> --broadcast
 */
contract DeployScript {

    // Uniswap V2 Router addresses for different networks
    address constant MAINNET_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant BASE_ROUTER = 0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24;
    address constant ARBITRUM_ROUTER = 0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24;

    function run() external {
        // Get deployer address from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying with address:", deployer);
        console.log("Balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy BaseLauncher (fee collector is deployer for now)
        BaseLauncher launcher = new BaseLauncher(deployer);
        console.log("BaseLauncher deployed at:", address(launcher));

        // Deploy LiquidityManager (use appropriate router for network)
        // Default to mainnet router, change based on network
        LiquidityManager liquidityManager = new LiquidityManager(MAINNET_ROUTER);
        console.log("LiquidityManager deployed at:", address(liquidityManager));

        vm.stopBroadcast();

        // Print deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("BaseLauncher:", address(launcher));
        console.log("LiquidityManager:", address(liquidityManager));
        console.log("Fee Collector:", deployer);
        console.log("Launch Fee:", launcher.launchFee());
        console.log("=========================\n");
    }

    // Helper function to get router based on chain ID
    function getRouter() internal view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == 1) return MAINNET_ROUTER; // Ethereum Mainnet
        if (chainId == 8453) return BASE_ROUTER; // Base
        if (chainId == 42161) return ARBITRUM_ROUTER; // Arbitrum

        revert("Unsupported network");
    }
}

// Minimal console library for logging
library console {
    function log(string memory message) internal pure {}
    function log(string memory message, address value) internal pure {}
    function log(string memory message, uint256 value) internal pure {}
}

// Minimal vm interface for scripting
interface Vm {
    function envUint(string memory key) external view returns (uint256);
    function addr(uint256 privateKey) external pure returns (address);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
