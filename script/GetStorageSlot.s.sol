// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.21;

//import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Script} from "forge-std/Script.sol";
import {Test, console2} from "forge-std/Test.sol";
import "../lib/forge-std/src/StdJson.sol";


// forge script script/GetStorageSlot.s.sol:GetStorageSlot
contract GetStorageSlot is Script {

    uint256 number;

    /**
     * @dev Store value in variable
     * @param num value to store
     */
    function store(uint256 num) public {
        number = num;
    }

    function run() public view{
        //console2.log("Chain id: %s", vm.toString(block.chainid));
        console2.log("Deployer address: %s, native balnce %s", msg.sender, msg.sender.balance);
        console2.log("envelop.storage.WNFTLegacy721 \n %s \n", vm.toString(
            keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTLegacy721")) - 1)) & ~bytes32(uint256(0xff))
        ));

        console2.log("openzeppelin.storage.ERC721 \n %s \n", vm.toString(
            keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC721")) - 1)) & ~bytes32(uint256(0xff))
        ));
        
        console2.log("openzeppelin.storage.Singleton721 \n %s \n", vm.toString(
            keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Singleton721")) - 1)) & ~bytes32(uint256(0xff))
        ));

        console2.log("envelop.storage.WNFTV2Envelop721 \n %s \n", vm.toString(
            keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTV2Envelop721")) - 1)) & ~bytes32(uint256(0xff))
        ));

    }
    
    // function getSlot(string memory _s) public view returns (bytes32){
    //     return keccak256(abi.encode(uint256(keccak256(abi.encode(_s)) - 1)) & ~bytes32(uint256(0xff));
    // }

    // function control() public pure returns (bytes32){
    //     return keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC721")) - 1)) & ~bytes32(uint256(0xff)); 
    // }

    // function control2() public pure returns (bytes32){
    //     return keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTLegacy721")) - 1)) & ~bytes32(uint256(0xff)); 
    // }
    // function control3() public pure returns (bytes32){
    //     return keccak256(abi.encode(uint256(keccak256("ubdn.storage.DeTrustModel_01_Executive")) - 1)) & ~bytes32(uint256(0xff)); 
    // }

    // function control4() public pure returns (bytes32){
    //     return keccak256(abi.encode(uint256(keccak256("ubdn.storage.DeTrustMultisigModel_01")) - 1)) & ~bytes32(uint256(0xff)); 
    // }

    // function control5() public pure returns (bytes32){
    //     return keccak256(abi.encode(uint256(keccak256("ubdn.storage.MultisigOffchainBase_01_Storage")) - 1)) & ~bytes32(uint256(0xff)); 
    // }
    
    
    // function control6() public pure returns (bytes32){
    //     return keccak256(abi.encode(uint256(keccak256("ubdn.storage.FeeManager_01_Storage")) - 1)) & ~bytes32(uint256(0xff)); 
    // }
    // function control7() public pure returns (bytes32){
    //     return keccak256(abi.encode(uint256(keccak256("ubdn.storage.MultisigOnchainBase_01_Storage")) - 1)) & ~bytes32(uint256(0xff)); 
    // }

    
}