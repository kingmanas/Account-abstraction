// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp} from "script/SendPackedUSerOp.s.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test{
    using MessageHashUtils for bytes32;

    MinimalAccount minimalAccount;
    DeployMinimal deployMinimal;
    HelperConfig helperConfig;
    ERC20Mock usdc;
    SendPackedUserOp userOp;

    uint256 constant AMOUNT = 1e18;
    address randomUser = makeAddr("user");

    function setUp() public {
        deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount ) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
        userOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)) , 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector , address(minimalAccount) , AMOUNT);

        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        assert(usdc.balanceOf(address(minimalAccount)) == AMOUNT);

    }

    function testIfNotOwnerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)) , 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector , address(minimalAccount) , AMOUNT);

        vm.prank(msg.sender);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryAccountOrOwner.selector);
        minimalAccount.execute(dest , value , functionData);
    }

    function testRecoverSignedOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)) , 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector , address(minimalAccount) , AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector , dest , value , functionData);
        PackedUserOperation memory packedUserOp = userOp.generateSignedUserOperation(executeCallData , helperConfig.getConfig() , address(minimalAccount));

        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        // Act
        address actualSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);

        // Assert
        assertEq(actualSigner , minimalAccount.owner());
 
    }

    function testValidationOfUserOps() public{
        assertEq(usdc.balanceOf(address(minimalAccount)) , 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector , address(minimalAccount) , AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector , dest , value , functionData);
        PackedUserOperation memory packedUserOp = userOp.generateSignedUserOperation(executeCallData , helperConfig.getConfig() , address(minimalAccount));

        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        // Act
        vm.prank(address(helperConfig.getConfig().entryPoint));
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);
        assertEq(validationData , 0);
    }
    
    function testEntryPointCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)) , 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector , address(minimalAccount) , AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector , dest , value , functionData);
        PackedUserOperation memory packedUserOp = userOp.generateSignedUserOperation(executeCallData , helperConfig.getConfig() , address(minimalAccount));

        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        vm.deal(address(minimalAccount) , 1e18);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        // Act
        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops , payable(randomUser));

        assertEq(usdc.balanceOf(address(minimalAccount)) , AMOUNT);
    }
}