// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script, console2} from "forge-std/Script.sol";
import "../lib/forge-std/src/StdJson.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {EnvelopWNFTFactory} from "../src/EnvelopWNFTFactory.sol";
import "../src/impl/WNFTV2Envelop721.sol";
import "../src/impl/WNFTLegacy721.sol";
import "../src/impl/WNFTMyshchWallet.sol";
import "../src/EnvelopLegacyWrapperBaseV2.sol";
import "../src/impl/WNFTV2IndexForEvent01.sol";


contract InteracteScript is Script {
    using stdJson for string;

    address payable nativeImpl = payable(0x53e5CA35761cD24D83479f9066e4C0281dEd59da);
    address payable legacyImpl = payable(0xB692f2f8bABC3e348484dBa1ef24F61F75D61cdB);
    address payable myshchImpl = payable(0x7b294BFa2E76058512adb0807Bddf5e34235a70a);
    address payable indexEvent01 = payable(0xbded9C8C786727499f13261cC34b997dfa260538);
    address payable relayer = payable(0xf4139ff4C97d189Db6D7F57849CBe22fAacEc688);


    address _factory = 0x431Db5c6ce5D85A0BAa2198Aa7Aa0E65d37a25c8;
    address _wrapper = 0x9ED82f27f05e0aa6A1eC7811518DeC0F788B5774;
    address owner = 0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E;
    address payable receiver = payable(0xf315B9006C20913D6D8498BDf657E778d4Ddf2c4);
    address niftsy = 0x5dB9f4C9239345308614604e69258C0bba9b437f;

    WNFTV2Envelop721 impl_native = WNFTV2Envelop721(nativeImpl);
    WNFTLegacy721 impl_legacy = WNFTLegacy721(legacyImpl);
    WNFTMyshchWallet impl_myshch = WNFTMyshchWallet(myshchImpl);
    EnvelopWNFTFactory factory = EnvelopWNFTFactory(_factory);
    EnvelopLegacyWrapperBaseV2 wrapper = EnvelopLegacyWrapperBaseV2(_wrapper);

    function run() public {
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            owner,
            "Envelop",
            "ENV",
            "https://api.envelop.is/metadata/",
            new address[](0),
            new bytes32[](0),
            new uint256[](0),
            ""
        );

        //address[] memory addrs1 = new address[](0);
        /*address[] memory addrs1 = new address[](1);
        addrs1[0] = relayer;
        WNFTV2Envelop721.InitParams memory initData = WNFTV2Envelop721.InitParams(
            owner,
            'Envelop',
            'ENV',
            'https://api.envelop.is/metadata/',
            addrs1,
            new bytes32[](0),
            new uint256[](0),
            ""
        );*/

        vm.startBroadcast();
        //address payable _wnftWallet2 = payable(impl_myshch.createWNFTonFactory(initData));
        address payable _wnftWallet = payable(impl_native.createWNFTonFactory(initData));
        //console2.log(_wnftWallet2);
        //address payable _wnftWallet2 = payable(0xA6BEfE30e866016Bf1Bb6cd6f1294bB8E96c8d1a);
        //address payable _wnftWalletLegacy = payable(0x6ce103d9241825b1B99355C45e8883d05eE6Bd9A);

        //1 IERC20(0x5dB9f4C9239345308614604e69258C0bba9b437f).transfer(_wnftWallet, 1e18);

        /*2 (bool success,) = _wnftWallet.call{value: 1000000000000000}("");
        require(success, "Failed to send Ether");*/

        /*WNFTMyshchWallet wnft = WNFTMyshchWallet(_wnftWallet2);
        //WNFTLegacy721 wnftLegacy = WNFTLegacy721(_wnftWalletLegacy);
        bytes memory _data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            receiver, 1e18
        );
        wnft.executeEncodedTx(niftsy, 0, _data);*/
        /*3 bytes memory _data = "";

        wnft.executeEncodedTx(receiver, 1e15, _data);*/

        /*ET.AssetItem memory original_nft = ET.AssetItem(ET.Asset(ET.AssetType.EMPTY, address(0)),0,0);
        EnvelopLegacyWrapperBaseV2.INData memory inData = EnvelopLegacyWrapperBaseV2.INData(
                original_nft, // inAsset
                address(0), //unWrapDestination
                new ET.Fee[](0), // fees 
                new ET.Lock[](0), // locks
                new ET.Royalty[](0), // royalties
                ET.AssetType.ERC721,
                uint256(0),        
                0x0000   //bytes2
        ); 
        
        ET.AssetItem memory wnftAsset = wrapper.wrap(
            inData,
            new ET.AssetItem[](0),   // collateral
            owner
        );

        address payable _wnftWalletLegacy = payable(wnftAsset.asset.contractAddress);

        WNFTLegacy721 wnftLegacy = WNFTLegacy721(_wnftWalletLegacy);
        console2.log(address(wnftLegacy));*/

        /* 5 (bool success,) = (_wnftWalletLegacy).call{value: 1000000000000000}("");
        require(success, "Failed to send Ether");

        IERC20(niftsy).transfer(_wnftWalletLegacy, 1e18);*/

        /*6 ET.AssetItem memory collateral = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, niftsy),0, 1e18 / 2);
        wnftLegacy.removeCollateral(collateral, owner);*/

        /*7 ET.AssetItem memory collateral = ET.AssetItem(ET.Asset(ET.AssetType.NATIVE, address(0)),0, _wnftWalletLegacy.balance);
        wnftLegacy.removeCollateral(collateral, owner);*/

        /*8 ET.AssetItem memory collateral = ET.AssetItem(ET.Asset(ET.AssetType.ERC20, niftsy),0, 1e18 / 2);
        ET.AssetItem[] memory colls = new ET.AssetItem[](1);
        colls[0] = collateral;
        wnftLegacy.unWrap(colls);*/

        vm.stopBroadcast();
    }
}
