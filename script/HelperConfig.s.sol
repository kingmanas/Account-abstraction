// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script , console2} from "lib/forge-std/src/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig{
        address entryPoint;
        address account;
    }

    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    address constant BURNER_WALLET = 0x42B5D6D5FEF406F5804Be42042D818e79c7d15cE;
    // address constant FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    }

    function getConfig() public returns(NetworkConfig memory){
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns(NetworkConfig memory) {
        if(chainId == LOCAL_CHAIN_ID){
                    return getOrCreateAnvilEthConfig();
        }
        else if (networkConfigs[chainId].account != address(0)){
            return networkConfigs[chainId];
        }
        else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getEthSepoliaConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig({entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032 , account: BURNER_WALLET});
    }
    function getZkSyncSepoliaConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig(address(0) , BURNER_WALLET);
    }

    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory){
        if(localNetworkConfig.account != address(0)){
            return localNetworkConfig;
        }

        console2.log("Deploying Mocks....");
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({entryPoint: address(entryPoint) ,account:ANVIL_DEFAULT_ACCOUNT });
        return localNetworkConfig;
    }
}