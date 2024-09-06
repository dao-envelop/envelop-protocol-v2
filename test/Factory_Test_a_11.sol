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

// try to withdraw original nft - erc721
contract Factory_Test_a_11 is Test {
    
    event Log(string message);

    uint256 public sendEtherAmount = 1e18;
    uint256 public sendERC20Amount = 3e18;
    uint256 timelock = 10000;
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
        uint256 tokenId = 0;
        ET.AssetItem memory original_nft = ET.AssetItem(ET.Asset(ET.AssetType.ERC721, address(erc721)),tokenId,0);
        bytes memory initCallData = abi.encodeWithSignature(
            impl_legacy.INITIAL_SIGN_STR(),
            address(this), // creator and owner 
            "LegacyWNFTNAME", 
            "LWNFT", 
            "https://api.envelop.is" ,
            //new ET.WNFT[](1)[0]
            ET.WNFT(
                original_nft, // inAsset
                new ET.AssetItem[](0),   // collateral
                address(1), //unWrapDestination 
                new ET.Fee[](0), // fees
                new ET.Lock[](0), // locks
                new ET.Royalty[](0), // royalties
                0x0000   //bytes2
            ) 
        );  

        address payable _wnftWallet = payable(factory.creatWNFT(address(impl_legacy), initCallData));
        //transfer original NFT to wnft storage
        erc721.transferFrom(address(this), _wnftWallet, tokenId);
                
        WNFTLegacy721 wnft = WNFTLegacy721(_wnftWallet);

        // try to withdraw original NFT
        wnft.removeCollateral(original_nft, address(1));
        //wnft.removeCollateral(original_nft, address(1));
        console2.log(erc721.ownerOf(tokenId));

        /*assertEq(address(this).balance, balanceBefore + sendEtherAmount / 2);
        assertEq(_wnftWallet.balance, 0);
        assertEq(erc20.balanceOf(_wnftWallet), 0);*/
    }
}