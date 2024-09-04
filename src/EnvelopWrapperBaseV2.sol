// SPDX-License-Identifier: MIT
// Envelop Wrapper for wNFT Legacy contracts

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/LibET.sol";
import "./utils/TokenService.sol";
import "./interfaces/IEnvelopWNFTFactory.sol";


contract EnvelopWrapperBaseV2 is Ownable, TokenService {

    // For back compatibility with Envelop web app
    struct INData {
        ET.AssetItem inAsset;
        address unWrapDestination;
        ET.Fee[] fees;
        ET.Lock[] locks;
        ET.Royalty[] royalties;
        ET.AssetType outType;
        uint256 outBalance;      //0- for 721 and any amount for 1155
        bytes2 rules;
    }

    IEnvelopWNFTFactory public immutable factory;
    
    // Map from wrapping asset type to wnft contract address and last minted id
    // Actualy `lastWNFTId` meaning now is just minted wnft count (like nonce)
    // For back compatibility with Envelop web app
    mapping(ET.AssetType => ET.NFTItem) public lastWNFTId;  
    // Map from wNFT address to it's type (721, 1155)
    mapping(address => ET.AssetType) public wnftTypes;

    
    
    constructor (address _factoryAddress) 
        Ownable(msg.sender)
    {
        factory = IEnvelopWNFTFactory(_factoryAddress); 
    }

    function wrap(
        INData calldata _inData, 
        ET.AssetItem[] calldata _collateral, 
        address _wrappFor
    ) 
        external 
        payable 
        returns (ET.AssetItem memory wnft)
    {
        // Calculate new wnftAddress
        address wnftAddress = factory.predictDeterministicAddress(
            lastWNFTId[_inData.outType].contractAddress, // implementation address
            keccak256(abi.encode(lastWNFTId[_inData.outType]))
        );

        // trainsfer inAsset and colateral
        if ( _inData.inAsset.asset.assetType != ET.AssetType.NATIVE &&
             _inData.inAsset.asset.assetType != ET.AssetType.EMPTY
        ) 
        {
            require(
                _mustTransfered(_inData.inAsset) == _transferSafe(
                    _inData.inAsset, 
                    msg.sender, 
                    wnftAddress
                ),
                "Suspicious asset for wrap"
            );
        }

        _addCollateral(wnftAddress, 1, _collateral);
        // Encode init string

        // create wnft

        // icrement nonce
        lastWNFTId[_inData.outType].tokenId ++;
        
        return ET.AssetItem(
            ET.Asset(_inData.outType, wnftAddress),
            1,  //!!!!!  TODO get from proxy TOKEN_ID
            _inData.outBalance  //Check for  721
        );
    }
     /////////////////////////////////////////////////////////////////////
    //                    Admin functions                              //
    /////////////////////////////////////////////////////////////////////
    function setWNFTId(
        ET.AssetType  _assetOutType, 
        address _wnftContract, 
        uint256 _tokenId
    ) external onlyOwner {
        require(_wnftContract != address(0), "No zero address");
        lastWNFTId[_assetOutType] = ET.NFTItem(_wnftContract, _tokenId);
        wnftTypes[_wnftContract] =  _assetOutType;
    }

    function _mustTransfered(ET.AssetItem calldata _assetForTransfer) 
        internal 
        pure 
        returns (uint256 mustTransfered) 
    {
        // Available for wrap assets must be good transferable (stakable).
        // So for erc721  mustTransfered always be 1
        if (_assetForTransfer.asset.assetType == ET.AssetType.ERC721) {
            mustTransfered = 1;
        } else {
            mustTransfered = _assetForTransfer.amount;
        }
    }

    function _addCollateral(
        address _wNFTAddress, 
        uint256 _wNFTTokenId, 
        ET.AssetItem[] calldata _collateral
    ) internal virtual 
    {
        _wNFTTokenId;
        // Process Native Colleteral
        // Fee ??
        if (msg.value > 0) {
            Address.sendValue(payable(_wNFTAddress), msg.value);
        }
       
        // Process Token Colleteral
        for (uint256 i = 0; i <_collateral.length; i ++) {
            if (_collateral[i].asset.assetType != ET.AssetType.NATIVE) {
                require(
                    _mustTransfered(_collateral[i]) == _transferSafe(
                        _collateral[i], 
                        msg.sender, 
                        _wNFTAddress
                    ),
                    "Suspicious asset for wrap"
                );
            }
        }
    }


	
}