// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {MultisigWallet} from "../src/MultisigWallet.sol";

contract DeployScript is Script {
    function run() external returns (MultisigWallet) {
        console.log("Starting MultisigWallet deployment...\n");
        
        // Get deployment configuration from environment or use defaults
        address[] memory initialOwners = getInitialOwners();
        uint256 requiredConfirmations = getRequiredConfirmations();
        
        console.log("Deployment Configuration:");
        console.log("Deployer:", msg.sender);
        console.log("Required confirmations:", requiredConfirmations);
        console.log("Initial owners:");
        for (uint i = 0; i < initialOwners.length; i++) {
            console.log("  -", initialOwners[i]);
        }
        
        vm.startBroadcast();
        
        MultisigWallet multisigWallet = new MultisigWallet(initialOwners, requiredConfirmations);
        
        vm.stopBroadcast();
        
        console.log("MultisigWallet deployed successfully!");
        console.log("Contract address:", address(multisigWallet));
        
        // Verify deployment
        console.log("Verifying deployment...");
        address[] memory owners = multisigWallet.getOwners();
        uint256 numConfirmations = multisigWallet.numConfirmationsRequired();
        
        console.log("Owners count:", owners.length);
        console.log("Required confirmations:", numConfirmations);
        console.log("Transaction count:", multisigWallet.getTransactionCount());
        
        // Fund the wallet if specified
        if (vm.envOr("FUND_WALLET", false)) {
            uint256 fundAmount = vm.envOr("FUND_AMOUNT", uint256(1 ether));
            console.log("Funding wallet with", fundAmount, "wei...");
            
            vm.startBroadcast();
            (bool success,) = address(multisigWallet).call{value: fundAmount}("");
            vm.stopBroadcast();
            
            require(success, "Failed to fund wallet");
            console.log("Wallet funded successfully");
        }
        
        console.log("Deployment completed successfully!");
        console.log("Next steps:");
        console.log("1. Verify the contract on block explorer");
        console.log("2. Test the multisig functionality");
        console.log("3. Add more owners if needed using addOwner function");
        console.log("4. Update required confirmations if needed");
        
        return multisigWallet;
    }
    
    function getInitialOwners() internal view returns (address[] memory) {
        // Try to get owners from environment variables
        try vm.envAddress("OWNER_1") returns (address owner1) {
            try vm.envAddress("OWNER_2") returns (address owner2) {
                try vm.envAddress("OWNER_3") returns (address owner3) {
                    address[] memory owners = new address[](3);
                    owners[0] = owner1;
                    owners[1] = owner2;
                    owners[2] = owner3;
                    return owners;
                } catch {
                    return getDefaultOwners();
                }
            } catch {
                return getDefaultOwners();
            }
        } catch {
            return getDefaultOwners();
        }
    }
    
    function getDefaultOwners() internal pure returns (address[] memory) {
        // Default test owners - CHANGE THESE FOR PRODUCTION
        address[] memory owners = new address[](3);
        owners[0] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Default Anvil account 1
        owners[1] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Default Anvil account 2
        owners[2] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Default Anvil account 3
        return owners;
    }
    
    function getRequiredConfirmations() internal view returns (uint256) {
        return vm.envOr("REQUIRED_CONFIRMATIONS", uint256(2));
    }
}
