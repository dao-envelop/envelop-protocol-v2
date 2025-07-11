// SPDX-License-Identifier: MIT
// Envelop V2, wNFT implementation

pragma solidity ^0.8.28;

import "./Singleton721.sol";
import "../interfaces/IEnvelopV2wNFT.sol";
import "../interfaces/IMyshchWalletwNFT.sol"; 
import "./WNFTV2Envelop721.sol";

/**
 * @dev Implementation of WNFT for Myshch Ecosystem
 */
contract WNFTMyshchWallet is WNFTV2Envelop721 
{

    uint256 public constant PERMANENT_TX_COST = 43_000; 
    uint256 public constant PERCENT_DENOMINATOR =  10_000;
    uint256 public constant DEFAULT_RELAYER_FEE = 100_000; // 10% from network fee


    struct WNFTMyshchWalletStorage {
        mapping(address => bool) approvedRelayer;
        uint256 relayerFeePercent;
    }
    
    /// https://docs.soliditylang.org/en/latest/contracts.html#transient-storage
    uint256 transient public gasLeftOnStart; 
    
    
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
    constructor(address _defaultFactory) 
        WNFTV2Envelop721(_defaultFactory)
    {
    }

        
    ////////////////////////////////////////////////////////////////////////
    // OZ init functions layout                                           //
    ////////////////////////////////////////////////////////////////////////  
    // In This implementation next params are supported:
    // WNFTV2Envelop721 hashedParams[0] - rules
    
    // WNFTV2Envelop721 numberParams[0] - simpleTimeLock
    // WNFTV2Envelop721 numberParams[1] - relayerFee
    
    // WNFTMyshchWallet addrParams[0] - default relayer
  
    function initialize(
        InitParams calldata _init
    ) public payable virtual override initializer 
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
        // in this param relayer wnft address could be passed
        if (_init.addrParams.length  >  0) {
            $.approvedRelayer[_init.addrParams[0]] = true;
        }

        // Relayer Fee set
        if (_init.numberParams.length  >  1) {
            $.relayerFeePercent = _init.numberParams[1];   
        } else {
            $.relayerFeePercent = DEFAULT_RELAYER_FEE;
        }

        
    }
    ////////////////////////////////////////////////////////////////////////

    function erc20TransferWithRefund(
        address _target,
        address _receiver,
        uint256 _amount
    )
        external
        onlyWnftOwner
        returns(uint256 refundAmount)          
    {
        IMyshchWalletwNFT(_receiver).setGasCheckPoint();
        bytes memory _data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            _receiver, _amount
        );
        super._executeEncodedTx(_target, 0, _data);
        refundAmount = IMyshchWalletwNFT(_receiver).getRefund(msg.sender);
    }


    function setGasCheckPoint() 
        external
        onlyAprrovedRelayer
    returns (uint256) 
    {
        gasLeftOnStart = gasleft();
        return gasLeftOnStart;
    }

    function getRefund(address _gasSpender) 
        external
        onlyAprrovedRelayer
        fixEtherBalance
    returns (uint256 send) 
    {
        send = (PERMANENT_TX_COST + _getGasDiff(gasLeftOnStart)) * tx.gasprice;
        require(
            send < PERMANENT_TX_COST * tx.gasprice * 2, 
            "Too much refund request"
        );
        send += _getFeeAmount(send);
        Address.sendValue(payable(_gasSpender), send); 
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

    function getRelayerFeePercentPt() external view returns(uint256) {
         WNFTMyshchWalletStorage storage $ = _getWNFTMyshchWalletStorage();
         return $.relayerFeePercent;
    }


    ////////////////////////////////////////////////////////////////
    //    ******************* internals ***********************   //
    ////////////////////////////////////////////////////////////////
    function _getGasDiff(uint256 _was) internal view returns (uint256 diff) {
        diff = _was - gasleft();
    }

    function _getFeeAmount(uint256 _in) internal view virtual returns(uint256 fee){
        WNFTMyshchWalletStorage storage $ = _getWNFTMyshchWalletStorage();
        fee = (_in * $.relayerFeePercent) / (100 * PERCENT_DENOMINATOR); 
    }

    function _onlyAprrovedRelayer(address _sender) internal view virtual {
        WNFTMyshchWalletStorage storage $ = _getWNFTMyshchWalletStorage();
        require($.approvedRelayer[_sender], "Only for approved relayer");

    }
}

