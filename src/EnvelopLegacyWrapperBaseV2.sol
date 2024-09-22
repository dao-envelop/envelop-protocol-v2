// SPDX-License-Identifier: MIT
// Envelop Wrapper for wNFT Legacy contracts

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/LibET.sol";
import "./utils/TokenService.sol";
import "./interfaces/IEnvelopWNFTFactory.sol";
import "./interfaces/IEnvelopV2wNFT.sol";



contract EnvelopLegacyWrapperBaseV2 is Ownable, TokenService {

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

    // Just against stack too deep
    struct NFTMetaDataPacked{
        address receiver;
        uint256 batchSize;
        string name;
        string symbol;
        string baseurl;

    }

    IEnvelopWNFTFactory public immutable factory;
    
    // Map from wrapping asset type to wnft(implementaion) contract address and last minted id
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
        return _wrap(_inData, _collateral, 
            NFTMetaDataPacked(
                _wrappFor,
                1,
                "LegacyEnvelopWNFTV2", 
                "LEWV2", 
                ""
            )
        );
    }

    function wrapBatch(
        INData[] calldata _inDataS, 
        ET.AssetItem[] calldata _collateralERC20, 
        address[] calldata _receivers
    )
        external
        payable
        returns (ET.AssetItem[] memory wnfts)
    {
         require(
            _inDataS.length == _receivers.length, 
            "Array params must have equal length"
        );
        wnfts = new  ET.AssetItem[](_inDataS.length);
        for (uint256 i = 0; i < _inDataS.length; i++) {
            wnfts[i] = _wrap(_inDataS[i], _collateralERC20, 
            NFTMetaDataPacked(
                _receivers[i], 
                _inDataS.length,
                "LegacyEnvelopWNFTV2", 
                "LEWV2", 
                ""
            )
        );

        }

    }

    

    function wrapWithCustomMetaData(
        INData calldata _inData, 
        ET.AssetItem[] calldata _collateral, 
        address _wrappFor,
        string memory name_,
        string memory symbol_,
        string memory _baseurl
    )  
        public 
        payable  
        returns (ET.AssetItem memory wnft) 
    {
        return _wrap(_inData, _collateral,  
            NFTMetaDataPacked(_wrappFor, 1, name_, symbol_, _baseurl)
        );

    }

    function wrapWithCustomMetaDataBatch(
        INData[] calldata _inDataS, 
        ET.AssetItem[] calldata _collateralERC20, 
        address[] calldata _receivers,
        string memory name_,
        string memory symbol_,
        string memory _baseurl
    )
        external
        payable
        //returns (ET.AssetItem[] memory wnfts)
    {
         require(
            _inDataS.length == _receivers.length, 
            "Array params must have equal length"
        );
        //wnfts = new  ET.AssetItem[](_inDataS.length); 

        for (uint256 i = 0; i < _inDataS.length; i++) {
             _wrap(_inDataS[i], _collateralERC20, 
                NFTMetaDataPacked(
                    _receivers[i], 
                    _inDataS.length,
                    name_, 
                    symbol_, 
                    _baseurl
                )
            );
        }

    }

    function addCollateralBatch(
        address[] calldata _wNFTAddress, 
        uint256[] calldata _wNFTTokenId, 
        ET.AssetItem[] calldata _collateralERC20
    ) public payable {
        require(_wNFTAddress.length == _wNFTTokenId.length, "Array params must have equal length");
        require(_collateralERC20.length > 0 || msg.value > 0, "Collateral not found");

         // cycle for wNFTs that need to be topup with collateral
        for (uint256 i = 0; i < _wNFTAddress.length; i ++){
            // Check  that support EnvelopV2 interface
            if ( _supportsERC165InterfaceUnchecked(
                    _wNFTAddress[i], 
                    type(IEnvelopV2wNFT).interfaceId
                ))
            {
                _addCollateral(_wNFTAddress[i],  _collateralERC20);
                _addCollateralNative(_wNFTAddress[i], _wNFTAddress.length);
            }
        }
        // Native Change return  - 1 wei return ?
        uint256 valuePerWNFT = msg.value / _wNFTAddress.length;
        if (valuePerWNFT * _wNFTAddress.length < msg.value ){
            address payable s = payable(msg.sender);
            s.transfer(msg.value - valuePerWNFT * _wNFTAddress.length);
        }
    }

    
    //  LOW LEVEL passthrough to factory methods  - NOT SUPPORTED in THIS IMPLEMENTATION
    // function creatWNFT(address _implementation, bytes memory _initCallData) 
    //     external 
    //     payable 
    //     returns(address wnft)
    // {
    //     // create wnft
    //      wnft = payable(
    //         factory.creatWNFT(
    //             _implementation,
    //             _initCallData
    //         )
    //     );

    // }


    // function creatWNFT(address _implementation, bytes memory _initCallData, bytes32 _salt) 
    //     external 
    //     payable 
    //     returns(address wnft)
    // {
    //     // create wnft
    //     wnft = payable(
    //         factory.creatWNFT(
    //             _implementation,
    //             _initCallData,
    //             _salt
    //         )
    //     );
        
    // }

    /////////////////////////////////////////////////////////////////////
    //                    Admin functions                              //
    /////////////////////////////////////////////////////////////////////
    function setWNFTId(
        ET.AssetType  _assetOutType, 
        address _wnftContract, 
        uint256 _tokenId
    ) 
        external 
        onlyOwner 
    {
        require(_wnftContract != address(0), "No zero address");
        lastWNFTId[_assetOutType] = ET.NFTItem(_wnftContract, _tokenId);
        wnftTypes[_wnftContract] =  _assetOutType;
    }
    //////////////////////////////////////////////////////////////////////

    function saltBase(ET.AssetType _wnftType) 
        public 
        view 
        returns(ET.NFTItem memory nextItem)

    {
        nextItem = lastWNFTId[_wnftType];
    }

    function _wrap(
        INData calldata _inData, 
        ET.AssetItem[] calldata _collateral, 
        //address _wrappFor,
        NFTMetaDataPacked memory _meta
        //uint256 _wNFTBatchSize
    ) 
        internal 
        returns (ET.AssetItem memory wnft)
    {
        ET.NFTItem memory implementation = lastWNFTId[_inData.outType];

        // Calculate new wnftAddress
        address wnftAddress = factory.predictDeterministicAddress(
            implementation.contractAddress, // implementation address
            keccak256(abi.encode(implementation))
        );

        // trainsfer inAsset and collateral
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

        _addCollateral(wnftAddress, _collateral);
        // Encode init string
        bytes memory initCallData;
        initCallData = abi.encodeWithSignature(
            IEnvelopV2wNFT(implementation.contractAddress).INITIAL_SIGN_STR(),
            _meta.receiver, 
            _meta.name, _meta.symbol, _meta.baseurl , 
            ET.WNFT(
                _inData.inAsset, // inAsset
                _collateral,   // collateral
                address(0), //unWrapDestination  TODO !!!Check implementation
                _inData.fees, // fees
                _inData.locks, // locks
                _inData.royalties, // royalties
                _inData.rules   //bytes2
            ) 
        );

        // create wnft
        address payable proxy = payable(
            factory.creatWNFT(
                implementation.contractAddress,
                initCallData,
                keccak256(abi.encode(implementation))
            )
        );

        // must add native ONLY AFTER PROXY CREATED, becouse there is an event
        // fallback function for Envelop Oracle
        _addCollateralNative(proxy, _meta.batchSize);

        assert(proxy == wnftAddress);

        // icrement nonce
        lastWNFTId[_inData.outType].tokenId ++;
        
        // construct answer
        bytes memory _answerFromProxy = Address.functionStaticCall(
                proxy,
                abi.encodeWithSignature("TOKEN_ID()")
        );
        return ET.AssetItem(
            ET.Asset(_inData.outType, wnftAddress),
            uint256(bytes32(_answerFromProxy)),
            _inData.outBalance  //Check for  721
        );
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
        ET.AssetItem[] calldata _collateral
    ) internal virtual 
    {
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

    function _addCollateralNative(address _wNFTAddress, uint256 _batchSize) 
        internal 
    {
        if (msg.value > 0) {
            Address.sendValue(payable(_wNFTAddress), msg.value / _batchSize);
        }
    }

     /**
     *         FROM OpenZeppelin
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     *
     * Some precompiled contracts will falsely indicate support for a given interface, so caution
     * should be exercised when using this function.
     *
     * Interface identification is specified in ERC-165.
     */
    function _supportsERC165InterfaceUnchecked(address account, bytes4 interfaceId) internal view returns (bool) {
        // prepare call
        bytes memory encodedParams = abi.encodeCall(IERC165.supportsInterface, (interfaceId));

        // perform static call
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly {
            success := staticcall(30000, account, add(encodedParams, 0x20), mload(encodedParams), 0x00, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0x00)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
    }


	
}