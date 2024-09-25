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
import "./SmartWallet.sol";

/**
 * @dev Implementation of WNFT that partial compatible with Envelop V1
 */
contract WNFTMyshchWallet is 
    Singleton721, 
    SmartWallet,
    IEnvelopV2wNFT,
    IMyshchWalletwNFT
    // ERC721HolderUpgradeable, 
    // ERC1155HolderUpgradeable 
{
    string public constant INITIAL_SIGN_STR = "initialize(address,string,string,string)";
    uint256 public constant ORACLE_TYPE = 2002;
    bytes2 public constant SUPPORTED_RULES = 0x0000; // Bin 0000000100000101; Dec 261
        // #### Envelop ProtocolV1 Rules !!! NOT All support in this implementation V2
    // 15   14   13   12   11   10   9   8   7   6   5   4   3   2   1   0  <= Bit number(dec)
    // ------------------------------------------------------------------------------------  
    //  1    1    1    1    1    1   1   1   1   1   1   1   1   1   1   1
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   |   |   |
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   |   |   +-No_Unwrap
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   |   +-No_Wrap (NOT SUPPORTED)
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   +-No_Transfer
    //  |    |    |    |    |    |   |   |   |   |   |   |   +-No_Collateral (NOT SUPPORTED)
    //  |    |    |    |    |    |   |   |   |   |   |   +-reserved_core
    //  |    |    |    |    |    |   |   |   |   |   +-reserved_core
    //  |    |    |    |    |    |   |   |   |   +-reserved_core  
    //  |    |    |    |    |    |   |   |   +-reserved_core
    //  |    |    |    |    |    |   |   |
    //  |    |    |    |    |    |   |   + - V2. always wnft URL|
    //  +----+----+----+----+----+---+ 
    //      for use in extendings
    
   
    // struct WNFTLegacy721Storage {
    //     ET.WNFT wnftData;
    // }

    // error InsufficientCollateral(ET.AssetItem declare, uint256 fact);
    // error WnftRuleViolation(bytes2 rule);
    // error RuleSetNotSupported(bytes2 unsupportedRules);

   
    
    
    //  event EnvelopRulesChanged(
    //     address indexed wrappedAddress,
    //     uint256 indexed wrappedId,
    //     bytes2 newRules
    // );

    
    // modifier ifUnlocked() {
    //     _checkLocks();
    //     _;
    // }

    modifier onlyWnftOwner() {
        _wnftOwnerOrApproved(msg.sender);
        _;
    }


    // keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTLegacy721")) - 1)) & ~bytes32(uint256(0xff))
    //bytes32 private constant WNFTLegacy721StorageLocation = 0xb25b7d902932741f4867febf64c52dbc3980210eefc4a36bf4280ce48f34a100;

    constructor() {
      _disableInitializers();
      emit EnvelopV2OracleType(ORACLE_TYPE, type(WNFTMyshchWallet).name);
    }

    function initialize(
        address _creator,
        string memory name_,
        string memory symbol_,
        string memory _tokenUrl
        //ET.WNFT memory _wnftData
        //ET.AssetItem memory _wnftData
    ) public initializer fixEtherBalance()
    {
        
        __WNFTMyshchWallet_init(name_, symbol_, _creator, _tokenUrl);
    }
        
    ////////////////////////////////////////////////////////////////////////
    // OZ init functions layout                                           //
    ////////////////////////////////////////////////////////////////////////    

    // function _getWNFTLegacy721Storage() private pure returns (WNFTLegacy721Storage storage $) {
    //     assembly {
    //         $.slot := WNFTLegacy721StorageLocation
    //     }
    // }

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __WNFTMyshchWallet_init(
        string memory name_, 
        string memory symbol_,
        address _creator,
        string memory _tokenUrl
        //ET.WNFT memory _wnftData
    ) internal onlyInitializing {
        __Singleton721_init(name_, symbol_, _creator, _tokenUrl);
        //__WNFTMyshchWallet_init_unchained(_wnftData, _creator);
    }

    function __WNFTMyshchWallet_init_unchained(
        //ET.WNFT memory _wnftData,
        //address _creator
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

    
    function approveHiden(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, _msgSender(), false);
    }

    // function transferFrom(address from, address to, uint256 tokenId) public override {
    //     WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
    //     // Check No Transfer rule
    //     if (_checkRule(0x0004, $.wnftData.rules)) {
    //         revert WnftRuleViolation(0x0004);
    //     }
    //     // TODO  deny self address transfer ?????
    //     super.transferFrom(from, to, tokenId);
    // }

   

     /**
     * @dev Use this method for interact any dApps onchain
     * @param _target address of dApp smart contract
     * @param _value amount of native token in tx(msg.value)
     * @param _data ABI encoded transaction payload
     */
    function executeEncodedTx(
        address _target,
        uint256 _value,
        bytes memory _data
    ) 
        external 
        //ifUnlocked()
        onlyWnftOwner()
        returns (bytes memory r) 
    {
        r = super._executeEncodedTx(_target, _value, _data);
    }

    /**
     * @dev Use this method for interact any dApps onchain, executing as one batch
     * @param _targetArray addressed of dApp smart contract
     * @param _valueArray amount of native token in every tx(msg.value)
     * @param _dataArray ABI encoded transaction payloads
     */
    function executeEncodedTxBatch(
        address[] calldata _targetArray,
        uint256[] calldata _valueArray,
        bytes[] memory _dataArray
    ) 
        external 
        //ifUnlocked()
        onlyWnftOwner() 
        returns (bytes[] memory r) 
    {
    
        r = super._executeEncodedTxBatch(_targetArray, _valueArray, _dataArray);
    }

    function erc20TransferWithRefund(
        address _target,
        address _receiver,
        uint256 _amount
    )
        external
        onlyWnftOwner()  
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
     */
     // TODO  TESTS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual  
        override(ERC721Upgradeable, ERC1155HolderUpgradeable, IERC165) 
        returns (bool) 
    {
        //TODO  add current contract interface
       return interfaceId == type(IEnvelopV2wNFT).interfaceId || super.supportsInterface(interfaceId);
    }

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

    
    
    function  _wnftOwnerOrApproved(address _sender) internal view virtual {
        address currOwner = ownerOf(TOKEN_ID);
        require(
            currOwner == _sender ||
            isApprovedForAll(currOwner, _sender) ||
            getApproved(TOKEN_ID) == _sender,
            "Only for wNFT owner"
        );
    }
}

