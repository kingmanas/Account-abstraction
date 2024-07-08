// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED , SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
contract MinimalAccount is IAccount , Ownable {

    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryAccountOrOwner();
    error MinimalAccount__ExecutionCallFailed(bytes);
    
    IEntryPoint immutable private i_entryPoint;

    modifier requireFromEtnryPoint(){
        if(msg.sender != address(i_entryPoint)){
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }
    modifier requireFromEntryPointOrOwner(){
        if(msg.sender != address(i_entryPoint) && msg.sender != owner()){
            revert MinimalAccount__NotFromEntryAccountOrOwner();
        }
        _;
    }
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    // A signature is valid if its the contract(minimalAccount) owner
     function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external requireFromEtnryPoint returns (uint256 validationData) 
    {
        validationData = _validateSignature(userOp , userOpHash);
        _payPreFunds(missingAccountFunds);

    }

    function execute(address dest , uint256 value , bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success , bytes memory result) = dest.call{value: value}(functionData);
        if(!success){
            revert MinimalAccount__ExecutionCallFailed(result);
        }
    }  

    function _validateSignature(PackedUserOperation calldata userOp , bytes32 userOpHash) internal view returns(uint256 validationData){
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash ,userOp.signature);
        if( signer != owner()){
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
       
    }

    function _payPreFunds(uint256 missingFunds) internal {
        if(missingFunds != 0){
            (bool success ,) = payable(msg.sender).call{value: missingFunds , gas : type
            (uint256).max}("");
            (success);
        }
    }

    function getEntryPoint() external view returns(address){
        return address(i_entryPoint);
    }
}