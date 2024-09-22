// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import "../src/impl/WNFTLegacy721.sol";
import "../src/impl/WNFTWallet.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// spender of wnft withdraw eth from collateral
// check eth events
// try to unWrap - user is not owner and does not have allowance - revert
contract Factory_Test_a_01 is Test {
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    MockERC721 public erc721;
    EnvelopWNFTFactory public factory;
    WNFTLegacy721 public impl_legacy;

    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC');
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTLegacy721();
        factory.setWrapperStatus(address(this), true); // set wrapper
    }
    
    function test_create_legacy() public {
        bytes memory initCallData = abi.encodeWithSignature(
            impl_legacy.INITIAL_SIGN_STR(),
            address(this), // creator and owner 
            "LegacyWNFTNAME", 
            "LWNFT", 
            "https://api.envelop.is" ,
            //new ET.WNFT[](1)[0]
            ET.WNFT(
                ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)),0,0), // inAsset
                new ET.AssetItem[](0),   // collateral
                address(this), //unWrapDestination 
                new ET.Fee[](0), // fees
                new ET.Lock[](0), // locks
                new ET.Royalty[](0), // royalties
                0x0105   //bytes2
            ) 
        );  

        vm.prank(address(100));
        vm.expectRevert("Only for Envelop Authorized");
        address payable _wnftWallet = payable(factory.creatWNFT(address(impl_legacy), initCallData));

        _wnftWallet = payable(factory.creatWNFT(address(impl_legacy), initCallData));
        assertNotEq(_wnftWallet, address(impl_legacy));
        console2.log(_wnftWallet);

        // send eth to wnft wallet
        vm.prank(address(this));
        vm.expectEmit();
        emit IEnvelopV2wNFT.EtherReceived(sendEtherAmount, sendEtherAmount, address(this));
        (bool sent, bytes memory data) = _wnftWallet.call{value: sendEtherAmount}("");
        // suppress solc warnings 
        sent;
        data;
        assertEq(address(_wnftWallet).balance, sendEtherAmount);
        
        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);
        
        wnft.setApprovalForAll(address(2), true);

        vm.prank(address(2));
        // try to withdraw eth from collateral
        ET.AssetItem memory collateral = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)),0,sendEtherAmount / 2);
        vm.expectEmit();
        emit WNFTWallet.EtherBalanceChanged(sendEtherAmount, sendEtherAmount / 2, 0, address(2));
        wnft.removeCollateral(collateral, address(2));
        assertEq(address(2).balance, sendEtherAmount / 2);
        assertEq(address(_wnftWallet).balance, sendEtherAmount / 2);

        data = "";
        vm.prank(address(2));
        vm.expectEmit();
        emit WNFTWallet.EtherBalanceChanged(sendEtherAmount / 2, 0, 0, address(2));
        wnft.executeEncodedTx(address(2), sendEtherAmount / 2, data); 
        assertEq(address(2).balance, sendEtherAmount);
        assertEq(_wnftWallet.balance,0);

        ET.AssetItem[] memory collaterals = new ET.AssetItem[](0);
        vm.prank(address(100));
        vm.expectRevert("Only for wNFT owner");
        wnft.unWrap(collaterals);
    }

    // unsupported rules
    function test_checkRules() public {
        bytes memory initCallData = abi.encodeWithSignature(
            impl_legacy.INITIAL_SIGN_STR(),
            address(this), // creator and owner 
            "LegacyWNFTNAME", 
            "LWNFT", 
            "https://api.envelop.is" ,
            //new ET.WNFT[](1)[0]
            ET.WNFT(
                ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)),0,0), // inAsset
                new ET.AssetItem[](0),   // collateral
                address(this), //unWrapDestination 
                new ET.Fee[](0), // fees
                new ET.Lock[](0), // locks
                new ET.Royalty[](0), // royalties
                0x0002   //bytes2
            ) 
        );  

        bytes2 rule = 0x0002;
        vm.expectRevert();
        address payable _wnftWallet = payable(factory.creatWNFT(address(impl_legacy), initCallData));
    }
}