//SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {Script} from "forge-std/src/Script.sol";
import {MyServiceManager} from "../src/MyServiceManager.sol";
import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {AVSDirectory} from "eigenlayer-contracts/src/contracts/core/AVSDirectory.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";

contract DeployMyServiceManager is Script {

    address internal constant AVS_DIRECTORY = 0xdAbdB3Cd346B7D5F5779b0B614EdE1CC9DcBA5b7;
    address internal constant DELEGATION_MANAGER = 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A;
    
    address internal deployer;
    address internal operator;
    MyServiceManager serviceManager;

    function setUp() public virtual {
        deployer =vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        operator =vm.rememberKey(vm.envUint("OPERATOR_PRIVATE_KEY"));
        vm.label(deployer, "deployer");
        vm.label(operator, "operator");
    }

    function run() public{

        vm.startBroadcast(deployer);
        serviceManager=new MyServiceManager(AVS_DIRECTORY);
        vm.stopBroadcast();

        IDelegationManager delegationManager = IDelegationManager(
            DELEGATION_MANAGER
        );

        IDelegationManager.operatorDetails
                memory operatorDetails = IDelegationManager.OperatorDetails({
                earningsReceiver:operator,
                delegationApprover: address(0),
                stakerOptOutWindowBlocks:0
            });

        vm.startBroadcast(operator);
        delegationManager.registerAsOperator(operatorDetails,"");
        vm.stopBroadcast();  

        AVSDirectory avsDirectory= AVSDirectory(AVS_DIRECTORY); 
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, operator));
        uint256 expiry = block.timestamp + 1 hours;

        bytes32 operatorRegistrationDigestHash = avsDirectory
              .calculateOperatorAVSRegistrationDigestHash(
                operator,
                address(serviceManager),
                salt,
                expiry
              );

        (uint8 v,bytes32 r, bytes32 s)=vm.sign(
            vm.envUint("OPERATOR_PRIVATE_KEY"),
            operatorRegistrationDigestHash
        ) ;

        bytes memory signature = abi.encodePacked(r,s,v);  

        ISignatureUtils.SignatureWithSaltAndExpiry
             memory operatorSignature = ISignatureUtils
                   .SignatureWithSaltAndExpiry({
                    signature:signature,
                    salt:salt,
                    expiry:expiry
                   });

        vm.startBroadcast(operator);
        MyServiceManager.registerOperatorToAVS(operator, operatorSignature);  
        vm.stopBroadcast();          
    }
}