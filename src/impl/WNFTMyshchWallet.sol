// SPDX-License-Identifier: MIT
// Envelop V2, wNFT implementation

pragma solidity ^0.8.20;

// import "@Uopenzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
//import "@Uopenzeppelin/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "./Singleton721.sol";
//import "../utils/LibET.sol";
//import "../utils/TokenService.sol";
import "../interfaces/IEnvelopV2wNFT.sol";
import "../interfaces/IMyshchWalletwNFT.sol"; 
import "./WNFTV2Envelop721.sol";

/**
 * @dev Implementation of WNFT that partial compatible with Envelop V1
 */
contract WNFTMyshchWallet is WNFTV2Envelop721 
{

    constructor(address _defaultFactory) 
        WNFTV2Envelop721(_defaultFactory)
    {
      
    }

        
    ////////////////////////////////////////////////////////////////////////
    // OZ init functions layout                                           //
    ////////////////////////////////////////////////////////////////////////    
    function initialize(
        InitParams calldata _init
    ) public virtual override initializer 
    {
        
        __WNFTMyshchWallet_init(_init);
    }

    // function _getWNFTLegacy721Storage() private pure returns (WNFTLegacy721Storage storage $) {
    //     assembly {
    //         $.slot := WNFTLegacy721StorageLocation
    //     }
    // }

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __WNFTMyshchWallet_init(
        InitParams calldata _init
    ) internal onlyInitializing {
         __WNFTV2Envelop721_init(_init);
         __WNFTMyshchWallet_init_unchained(_init);
    }

    function __WNFTMyshchWallet_init_unchained(
        InitParams calldata _init
    ) internal onlyInitializing {
        
        // emit WrappedV1(
        //     _wnftData.inAsset.asset.contractAddress,
        //     address(this),
        //     _wnftData.inAsset.tokenId,
        //     TOKEN_ID,
        //     _creator,
        //     msg.value, //  TODO  Batch??
        //     _wnftData.rules
        // );
    }
    ////////////////////////////////////////////////////////////////////////

    

    function erc20TransferWithRefund(
        address _target,
        address _receiver,
        uint256 _amount
    )
        external
        //onlyWnftOwner()  
    {
        uint256 gasBefore = gasleft();
        bytes memory _data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            _receiver, _amount
        );
        super._executeEncodedTx(_target, 0, _data);
        IMyshchWalletwNFT(_receiver).getRefund(gasBefore);
    }

    function getRefund(uint256 _gasLeft) 
        external
    // Check allowance    
    returns (uint256 send) 
    {
        send = (_gasLeft - gasleft());// * tx.gasprice;
        Address.sendValue(payable(msg.sender), send); 
    }

    ////////////////////////////////////////////////////////////////////////////
    /////                    GETTERS                                       /////
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @dev See {IERC165-supportsInterface}.
    

    // function wnftInfo(uint256 tokenId) external view returns (ET.WNFT memory) {
    //     tokenId; // suppress solc warn
    //     WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
    //     return $.wnftData;
    // }

    // function tokenURI(uint256 tokenId) public view  override returns (string memory uri_) {
    //     WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
    //     uri_ = super.tokenURI(tokenId);

    //     // V2 wnft RULE for override inAsset URL
    //     if (_checkRule(0x0100, $.wnftData.rules)) {    
    //         return uri_;
    //     } 
    //     if ($.wnftData.inAsset.asset.assetType == ET.AssetType.ERC721)
    //     {
    //         if (_ownerOf($.wnftData.inAsset) == address(this)) {
    //             // method from TokenService
    //             uri_ = _getURI($.wnftData.inAsset);
    //         }
    //     } else if ($.wnftData.inAsset.asset.assetType == ET.AssetType.ERC1155)
    //     {
    //         if (_balanceOf($.wnftData.inAsset, address(this)) > 0 ) {
    //             // method from TokenService
    //             uri_ = _getURI($.wnftData.inAsset);
    //         }

    //     }
        
    // }
    ////////////////////////////////////////////////////////////////
    //    ******************* internals ***********************   //
    //    ******************* internals ***********************   //
    ////////////////////////////////////////////////////////////////

    // 0x00 - TimeLock
    // 0x01 - TransferFeeLock   - UNSUPPORTED IN THIS IMPLEMENATION
    // 0x02 - Personal Collateral count Lock check  - UNSUPPORTED IN THIS IMPLEMENATION
    // function _checkLocks() internal virtual {
    //     WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
    //     ET.Lock[] memory lck = $.wnftData.locks;
    //     for (uint256 i = 0; i < lck.length; ++ i) {
    //         if (lck[i].lockType == 0x00) {
    //             require(
    //                 lck[i].param <= block.timestamp,
    //                 "TimeLock error"
    //             );
    //         }
    //     }
    // }
    

    /**
     * @dev Use for check rules above.
     */
    // function _checkRule(bytes2 _rule, bytes2 _wNFTrules) internal pure returns (bool isSet) {
    //     isSet =_rule == (_rule & _wNFTrules);
    // }

    // function _isValidRules(bytes2 _rules) internal pure virtual returns (bool ok) {
    //     if (!_checkRule(_rules, SUPPORTED_RULES)) {
    //         revert RuleSetNotSupported(_rules & SUPPORTED_RULES ^ _rules); //  return 1 in UNsupported digits
    //     }
    //     ok = true;

    // }

    // function _isValidLockRecord(ET.Lock memory _lockRec) internal virtual view {

    // }

}

