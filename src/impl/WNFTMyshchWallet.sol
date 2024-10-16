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

    uint256 public constant PERMANENT_TX_COST = 0;
    uint256 public immutable PERCENT_DENOMINATOR = 10000;
    uint256 public immutable FEE_PERCENT;


    struct WNFTMyshchWalletStorage {
        mapping(address => bool) approvedRelayer;
    }

    uint256 public gasLeftOnStart; // Move to private struct
    
    modifier onlyApproved() {
        _onlyApproved(msg.sender);
        _;
    }
    
    modifier onlyAprrovedRelayer() {
        _onlyAprrovedRelayer(msg.sender);
        _;
    }

    
    ///////////////////////////////////////////////////////
    ///                 OZ  Storage pattern              //
    ///////////////////////////////////////////////////////

    // keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTV2Envelop721")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant WNFTMyshchWalletStorageLocation = 0xb7e82b5c82f21c1cdf373ea16f6379953c1d1abd353934dd29dd5c1151900100;
    function _getWNFTMyshchWalletStorage() private pure returns (WNFTMyshchWalletStorage storage $) {
        assembly {
            $.slot := WNFTMyshchWalletStorageLocation
        }
    }
    ///////////////////////////////////////////////////////
    constructor(address _defaultFactory, uint256 _feePercent) 
        WNFTV2Envelop721(_defaultFactory)
    {
       require(_feePercent < 2 * PERCENT_DENOMINATOR, "Fee cant be morej");
       FEE_PERCENT = _feePercent;
    }

        
    ////////////////////////////////////////////////////////////////////////
    // OZ init functions layout                                           //
    ////////////////////////////////////////////////////////////////////////  
    // In This implementation next params are supported:
    // WNFTV2Envelop721 hashedParams[0] - rules
    // WNFTV2Envelop721 numberParams[0] - simpleTimeLock
    // WNFTMyshchWallet addrParams[0] - default relayer
  
    function initialize(
        InitParams calldata _init
    ) public virtual override initializer 
    {
        
        __WNFTMyshchWallet_init(_init);
    }

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
        WNFTMyshchWalletStorage storage $ = _getWNFTMyshchWalletStorage();
        if (_init.addrParams.length  >  0) {
            $.approvedRelayer[_init.addrParams[0]] = true;   
        }
        
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
        onlyWnftOwner()  
    {
        IMyshchWalletwNFT(_receiver).setGasCheckPoint();
        //uint256 gasBefore = gasleft();
        bytes memory _data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            _receiver, _amount
        );
        super._executeEncodedTx(_target, 0, _data);
        uint256 refundAmount = IMyshchWalletwNFT(_receiver).getRefund();
        Address.sendValue(payable(msg.sender), refundAmount); 
    }

    function setGasCheckPoint() 
        external
        onlyAprrovedRelayer
    returns (uint256) 
    {
        gasLeftOnStart = gasleft();
        return gasLeftOnStart;
    }

    function getRefund() 
        external
        onlyAprrovedRelayer
    returns (uint256 send) 
    {
        send = (PERMANENT_TX_COST + gasLeftOnStart - gasleft()) * tx.gasprice;
        if (FEE_PERCENT > 0 ){
            send += send * FEE_PERCENT / (100 * PERCENT_DENOMINATOR); 
        }
        Address.sendValue(payable(msg.sender), send); 
    }

    function setRelayerStatus(address _relayer, bool _status) 
        external 
        onlyWnftOwner 
    {
         WNFTMyshchWalletStorage storage $ = _getWNFTMyshchWalletStorage();
         $.approvedRelayer[_relayer] = _status;
    }

    ////////////////////////////////////////////////////////////////////////////
    /////                    GETTERS                                       /////
    ////////////////////////////////////////////////////////////////////////////

    function getRelayerStatus(address _relayer) external view returns(bool) {
         WNFTMyshchWalletStorage storage $ = _getWNFTMyshchWalletStorage();
         return $.approvedRelayer[_relayer];
    }

    ////////////////////////////////////////////////////////////////
    //    ******************* internals ***********************   //
    ////////////////////////////////////////////////////////////////
    
    function  _onlyApproved(address _sender) internal view virtual {
        address currOwner = ownerOf(TOKEN_ID);
        require(
            //currOwner == _sender ||
            isApprovedForAll(currOwner, _sender) ||
            getApproved(TOKEN_ID) == _sender,
            "Only for apprved addresses"
        );
    }

    function _onlyAprrovedRelayer(address _sender) internal view virtual {
        WNFTMyshchWalletStorage storage $ = _getWNFTMyshchWalletStorage();
        require($.approvedRelayer[_sender], "Only for apprved relayer");

    }

}

