//SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

contract MyServiceManager {

    using ECDSA for bytes32;

    address public immutable avsDirectory;
    uint32 public latestTaskNum;
    mapping(address => bool) public operatorRegistered;
    mapping(uint32 => bytes32) public allTaskHashes;
    mapping(address => mapping(uint32 => bytes)) public allTaskResponses;

    event NewTaskCreated(uint32 indexed taskIndex, Task task);

    event TaskResponded(
        uint32 indexed taskIndex,
        Task task,
        bool isSafe,
        address operator
    );

    struct Task {

        string contents;
        uint32 taskCreatedBlock;

    }

    modifier onlyOperator() {
        require(operatorRegistered[msg.sender],"Operator must be caller");
        _;
    }

    constructor(address _avsDirectory) {
        avsDirectory = _avsDirectory;
    }

    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external {
        IAVSDirectory(avsDirectory).registerOperatorToAVS(operator, operatorSignature);

        operatorRegistered[operator] = true;
    }

    function deregisterOperatorFromAVS(address operator) external onlyOperator {
        require(msg.sender == operator, "Caller must be operator");
        IAVSDirectory(avsDirectory).deregisterOperatorFromAVS(operator);
        operatorRegistered[operator] = false;
    }

    function createNewTask(
        string memory contents
    ) external returns (Task memory) {

        Task memory newTask;

        newTask.contents = contents;
        newTask.taskCreatedBlock = uint32(block.number);
        

        allTaskHashes[latestTaskNum] = keccak256(abi.encode(newTask));
        emit NewTaskCreated(latestTaskNum, newTask);
        latestTaskNum += 1;

        return newTask;

        
    }

    function respondToTask(
        Task calldata task,
        uint32 referenceTaskIndex,
        bool isSafe,
        bytes memory signature
    ) external onlyOperator{

        require(
            keccak256(abi.encode(task)) == allTaskHashes[referenceTaskIndex],
            "Task hash does not match"
        );

        require(allTaskResponses[msg.sender][referenceTaskIndex].length == 0, "Operator has already responded to this task");

        bytes32 messageHash = keccak256(abi.encodePacked(isSafe, task.contents));

        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        if(ethSignedMessageHash.recover(signature) != msg.sender){
            revert("signature is invalid");
        }

        allTaskResponses[msg.sender][referenceTaskIndex] = signature;

        emit TaskResponded(
            referenceTaskIndex,
            task,
            isSafe,
            msg.sender
        );
    
    }


}


