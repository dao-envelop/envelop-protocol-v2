// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "forge-std/console.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import {MockERC721} from "../src/mock/MockERC721.sol";
import {MockERC20} from "../src/mock/MockERC20.sol";
import "../src/impl/WNFTLegacy721.sol";
//import "../src/impl/Singleton721.sol";
//import {ET} from "../src/utils/LibET.sol";

// make approve
contract Factory_Test_a_07 is Test {
    
    error ERC721InvalidApprover(address approver);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    MockERC721 public erc721;
    MockERC20 public erc20;
    EnvelopWNFTFactory public factory;
    WNFTLegacy721 public impl_legacy;

    receive() external payable virtual {}
    function setUp() public {
        erc721 = new MockERC721('Mock ERC721', 'ERC721');
        erc20 = new MockERC20('Mock ERC20', 'ERC20');
        factory = new EnvelopWNFTFactory();
        impl_legacy = new WNFTLegacy721();
        factory.setWrapperStatus(address(this), true); // set wrapper
    }
    
    function test_create_legacy() public {
        ET.Lock[] memory locks = new ET.Lock[](1);
        locks[0] = ET.Lock(0x00, block.timestamp + 10000);
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
                address(0), //unWrapDestination 
                new ET.Fee[](0), // fees
                locks, // locks
                new ET.Royalty[](0), // royalties
                0x0000   //bytes2
            ) 
        );    

        address payable _wnftWallet = payable(factory.creatWNFT(address(impl_legacy), initCallData));
        assertNotEq(_wnftWallet, address(impl_legacy));

        // send erc20 to wnft wallet
        erc20.transfer(_wnftWallet, sendERC20Amount);
        
        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);
        console2.log("Owner of wnft: %s", wnft.ownerOf(wnft.TOKEN_ID()));
                
        uint256 tokenId = impl_legacy.TOKEN_ID();
        vm.prank(address(2)); // by non-owner
        vm.expectRevert(
            abi.encodeWithSelector(ERC721InvalidApprover.selector, address(2))
        );
        wnft.approveHiden(address(10), tokenId);
        
        wnft.approveHiden(address(1), tokenId);
        assertEq(wnft.getApproved(tokenId), address(1));

        // transfer and check approve
        wnft.transferFrom(address(this), address(2), tokenId);
        assertEq(wnft.getApproved(tokenId), address(0));
    }
}