// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MultisigWallet} from "../src/MultisigWallet.sol";

contract MultisigWalletTest is Test {
    MultisigWallet public multisigWallet;
    
    address public owner1 = makeAddr("owner1");
    address public owner2 = makeAddr("owner2");
    address public owner3 = makeAddr("owner3");
    address public owner4 = makeAddr("owner4");
    address public nonOwner = makeAddr("nonOwner");
    address public recipient = makeAddr("recipient");
    
    address[] public initialOwners;
    
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    event AddOwner(address indexed owner);
    event RemoveOwner(address indexed owner);
    event ChangeRequirement(uint numConfirmationsRequired);
    event Deposit(address indexed sender, uint amount, uint balance);

    function setUp() public {
        initialOwners.push(owner1);
        initialOwners.push(owner2);
        initialOwners.push(owner3);
        
        multisigWallet = new MultisigWallet(initialOwners, 2);
        
        // Fund accounts
        vm.deal(owner1, 10 ether);
        vm.deal(owner2, 10 ether);
        vm.deal(owner3, 10 ether);
        vm.deal(nonOwner, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deployment_Success() public {
        address[] memory owners = multisigWallet.getOwners();
        assertEq(owners.length, 3);
        assertEq(owners[0], owner1);
        assertEq(owners[1], owner2);
        assertEq(owners[2], owner3);
        assertEq(multisigWallet.numConfirmationsRequired(), 2);
    }

    function test_Deployment_RevertIfNotEnoughOwners() public {
        address[] memory twoOwners = new address[](2);
        twoOwners[0] = owner1;
        twoOwners[1] = owner2;
        
        vm.expectRevert("owners required");
        new MultisigWallet(twoOwners, 2);
    }

    function test_Deployment_RevertIfInvalidConfirmationRequirement() public {
        vm.expectRevert("invalid number of required confirmations");
        new MultisigWallet(initialOwners, 1);
        
        vm.expectRevert("invalid number of required confirmations");
        new MultisigWallet(initialOwners, 4);
    }

    function test_Deployment_RevertIfDuplicateOwners() public {
        address[] memory duplicateOwners = new address[](3);
        duplicateOwners[0] = owner1;
        duplicateOwners[1] = owner1; // Duplicate
        duplicateOwners[2] = owner3;
        
        vm.expectRevert("owner not unique");
        new MultisigWallet(duplicateOwners, 2);
    }

    function test_Deployment_RevertIfZeroAddressOwner() public {
        address[] memory zeroOwners = new address[](3);
        zeroOwners[0] = owner1;
        zeroOwners[1] = address(0); // Zero address
        zeroOwners[2] = owner3;
        
        vm.expectRevert("invalid owner");
        new MultisigWallet(zeroOwners, 2);
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Receive_Success() public {
        uint256 amount = 1 ether;
        
        vm.expectEmit(true, false, false, true);
        emit Deposit(owner1, amount, amount);
        
        vm.prank(owner1);
        (bool success,) = address(multisigWallet).call{value: amount}("");
        assertTrue(success);
        
        assertEq(address(multisigWallet).balance, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        SUBMIT TRANSACTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SubmitTransaction_Success() public {
        bytes memory data = "";
        uint256 value = 1 ether;
        
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(owner1, 0, recipient, value, data);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, value, data);
        
        (address to, uint256 txValue, bytes memory txData, bool executed, uint256 numConfirmations) = 
            multisigWallet.getTransaction(0);
            
        assertEq(to, recipient);
        assertEq(txValue, value);
        assertEq(txData, data);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
        assertEq(multisigWallet.getTransactionCount(), 1);
    }

    function test_SubmitTransaction_RevertIfNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        multisigWallet.submitTransaction(recipient, 1 ether, "");
    }

    /*//////////////////////////////////////////////////////////////
                        CONFIRM TRANSACTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ConfirmTransaction_Success() public {
        // Submit transaction first
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 1 ether, "");
        
        vm.expectEmit(true, true, false, false);
        emit ConfirmTransaction(owner1, 0);
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        assertTrue(multisigWallet.isConfirmed(0, owner1));
        
        (, , , , uint256 numConfirmations) = multisigWallet.getTransaction(0);
        assertEq(numConfirmations, 1);
    }

    function test_ConfirmTransaction_RevertIfNotOwner() public {
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        multisigWallet.confirmTransaction(0);
    }

    function test_ConfirmTransaction_RevertIfTxDoesNotExist() public {
        vm.prank(owner1);
        vm.expectRevert("tx does not exist");
        multisigWallet.confirmTransaction(0);
    }

    function test_ConfirmTransaction_RevertIfAlreadyConfirmed() public {
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("tx already confirmed");
        multisigWallet.confirmTransaction(0);
    }

    /*//////////////////////////////////////////////////////////////
                        EXECUTE TRANSACTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ExecuteTransaction_Success() public {
        // Fund the wallet
        vm.prank(owner1);
        (bool success,) = address(multisigWallet).call{value: 2 ether}("");
        assertTrue(success);
        
        // Submit transaction
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 1 ether, "");
        
        // Confirm by two owners
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        uint256 recipientBalanceBefore = recipient.balance;
        
        vm.expectEmit(true, true, false, false);
        emit ExecuteTransaction(owner1, 0);
        
        vm.prank(owner1);
        multisigWallet.executeTransaction(0);
        
        uint256 recipientBalanceAfter = recipient.balance;
        assertEq(recipientBalanceAfter - recipientBalanceBefore, 1 ether);
        
        (, , , bool executed, ) = multisigWallet.getTransaction(0);
        assertTrue(executed);
    }

    function test_ExecuteTransaction_RevertIfNotEnoughConfirmations() public {
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("cannot execute tx");
        multisigWallet.executeTransaction(0);
    }

    function test_ExecuteTransaction_RevertIfAlreadyExecuted() public {
        // Fund the wallet
        vm.prank(owner1);
        (bool success,) = address(multisigWallet).call{value: 2 ether}("");
        assertTrue(success);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner1);
        multisigWallet.executeTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("tx already executed");
        multisigWallet.executeTransaction(0);
    }

    function test_ExecuteTransaction_RevertIfTxFails() public {
        // Submit transaction with more value than wallet balance
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 10 ether, "");
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("tx failed");
        multisigWallet.executeTransaction(0);
    }

    /*//////////////////////////////////////////////////////////////
                        REVOKE CONFIRMATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevokeConfirmation_Success() public {
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.expectEmit(true, true, false, false);
        emit RevokeConfirmation(owner1, 0);
        
        vm.prank(owner1);
        multisigWallet.revokeConfirmation(0);
        
        assertFalse(multisigWallet.isConfirmed(0, owner1));
        
        (, , , , uint256 numConfirmations) = multisigWallet.getTransaction(0);
        assertEq(numConfirmations, 0);
    }

    function test_RevokeConfirmation_RevertIfNotConfirmed() public {
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner1);
        vm.expectRevert("tx not confirmed");
        multisigWallet.revokeConfirmation(0);
    }

    function test_RevokeConfirmation_RevertIfAlreadyExecuted() public {
        // Fund the wallet
        vm.prank(owner1);
        (bool success,) = address(multisigWallet).call{value: 2 ether}("");
        assertTrue(success);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner1);
        multisigWallet.executeTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("tx already executed");
        multisigWallet.revokeConfirmation(0);
    }

    /*//////////////////////////////////////////////////////////////
                        OWNER MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AddOwner_Success() public {
        bytes memory addOwnerData = abi.encodeWithSignature("addOwner(address)", owner4);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(address(multisigWallet), 0, addOwnerData);
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        vm.expectEmit(true, false, false, false);
        emit AddOwner(owner4);
        
        vm.prank(owner1);
        multisigWallet.executeTransaction(0);
        
        assertTrue(multisigWallet.isOwner(owner4));
        
        address[] memory owners = multisigWallet.getOwners();
        assertEq(owners.length, 4);
        assertEq(owners[3], owner4);
    }

    function test_AddOwner_RevertIfCalledDirectly() public {
        vm.prank(owner1);
        vm.expectRevert("only wallet can add owner");
        multisigWallet.addOwner(owner4);
    }

    function test_AddOwner_RevertIfOwnerAlreadyExists() public {
        bytes memory addOwnerData = abi.encodeWithSignature("addOwner(address)", owner1);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(address(multisigWallet), 0, addOwnerData);
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("owner already exists");
        multisigWallet.executeTransaction(0);
    }

    function test_AddOwner_RevertIfZeroAddress() public {
        bytes memory addOwnerData = abi.encodeWithSignature("addOwner(address)", address(0));
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(address(multisigWallet), 0, addOwnerData);
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("invalid owner");
        multisigWallet.executeTransaction(0);
    }

    function test_RemoveOwner_Success() public {
        // First add a fourth owner
        bytes memory addOwnerData = abi.encodeWithSignature("addOwner(address)", owner4);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(address(multisigWallet), 0, addOwnerData);
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner1);
        multisigWallet.executeTransaction(0);
        
        // Now remove the fourth owner
        bytes memory removeOwnerData = abi.encodeWithSignature("removeOwner(address)", owner4);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(address(multisigWallet), 0, removeOwnerData);
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(1);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(1);
        
        vm.expectEmit(true, false, false, false);
        emit RemoveOwner(owner4);
        
        vm.prank(owner1);
        multisigWallet.executeTransaction(1);
        
        assertFalse(multisigWallet.isOwner(owner4));
        
        address[] memory owners = multisigWallet.getOwners();
        assertEq(owners.length, 3);
    }

    function test_RemoveOwner_RevertIfCalledDirectly() public {
        vm.prank(owner1);
        vm.expectRevert("only wallet can remove owner");
        multisigWallet.removeOwner(owner3);
    }

    function test_RemoveOwner_RevertIfNotAnOwner() public {
        bytes memory removeOwnerData = abi.encodeWithSignature("removeOwner(address)", nonOwner);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(address(multisigWallet), 0, removeOwnerData);
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("not an owner");
        multisigWallet.executeTransaction(0);
    }

    function test_RemoveOwner_RevertIfWouldGoBelowMinimum() public {
        bytes memory removeOwnerData = abi.encodeWithSignature("removeOwner(address)", owner3);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(address(multisigWallet), 0, removeOwnerData);
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("cannot remove owner");
        multisigWallet.executeTransaction(0);
    }

    function test_ChangeRequirement_Success() public {
        bytes memory changeReqData = abi.encodeWithSignature("changeRequirement(uint256)", 3);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(address(multisigWallet), 0, changeReqData);
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        vm.expectEmit(false, false, false, true);
        emit ChangeRequirement(3);
        
        vm.prank(owner1);
        multisigWallet.executeTransaction(0);
        
        assertEq(multisigWallet.numConfirmationsRequired(), 3);
    }

    function test_ChangeRequirement_RevertIfCalledDirectly() public {
        vm.prank(owner1);
        vm.expectRevert("only wallet can change requirement");
        multisigWallet.changeRequirement(3);
    }

    function test_ChangeRequirement_RevertIfInvalidRequirement() public {
        bytes memory changeReqData = abi.encodeWithSignature("changeRequirement(uint256)", 1);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(address(multisigWallet), 0, changeReqData);
        
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner1);
        vm.expectRevert("invalid requirement");
        multisigWallet.executeTransaction(0);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetOwners() public {
        address[] memory owners = multisigWallet.getOwners();
        assertEq(owners.length, 3);
        assertEq(owners[0], owner1);
        assertEq(owners[1], owner2);
        assertEq(owners[2], owner3);
    }

    function test_GetTransactionCount() public {
        assertEq(multisigWallet.getTransactionCount(), 0);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 1 ether, "");
        
        assertEq(multisigWallet.getTransactionCount(), 1);
    }

    function test_GetTransaction() public {
        bytes memory data = "0x1234";
        uint256 value = 1 ether;
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, value, data);
        
        (address to, uint256 txValue, bytes memory txData, bool executed, uint256 numConfirmations) = 
            multisigWallet.getTransaction(0);
            
        assertEq(to, recipient);
        assertEq(txValue, value);
        assertEq(txData, data);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CompleteWorkflow() public {
        // Fund the wallet
        vm.prank(owner1);
        (bool success,) = address(multisigWallet).call{value: 5 ether}("");
        assertTrue(success);
        
        // Submit multiple transactions
        vm.prank(owner1);
        multisigWallet.submitTransaction(recipient, 1 ether, "");
        
        vm.prank(owner2);
        multisigWallet.submitTransaction(recipient, 2 ether, "");
        
        // Confirm first transaction by multiple owners
        vm.prank(owner1);
        multisigWallet.confirmTransaction(0);
        
        vm.prank(owner2);
        multisigWallet.confirmTransaction(0);
        
        // Execute first transaction
        vm.prank(owner3);
        multisigWallet.executeTransaction(0);
        
        // Verify first transaction executed
        (, , , bool executed, ) = multisigWallet.getTransaction(0);
        assertTrue(executed);
        assertEq(recipient.balance, 1 ether);
        
        // Confirm and execute second transaction
        vm.prank(owner1);
        multisigWallet.confirmTransaction(1);
        
        vm.prank(owner3);
        multisigWallet.confirmTransaction(1);
        
        vm.prank(owner2);
        multisigWallet.executeTransaction(1);
        
        // Verify second transaction executed
        (, , , bool executed2, ) = multisigWallet.getTransaction(1);
        assertTrue(executed2);
        assertEq(recipient.balance, 3 ether);
    }

    function test_FuzzSubmitTransaction(address to, uint256 value, bytes calldata data) public {
        vm.assume(to != address(0));
        vm.assume(value <= 100 ether);
        
        vm.prank(owner1);
        multisigWallet.submitTransaction(to, value, data);
        
        (address txTo, uint256 txValue, bytes memory txData, bool executed, uint256 numConfirmations) = 
            multisigWallet.getTransaction(0);
            
        assertEq(txTo, to);
        assertEq(txValue, value);
        assertEq(txData, data);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }
}
