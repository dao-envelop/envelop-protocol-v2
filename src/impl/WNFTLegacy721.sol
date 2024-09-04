// SPDX-License-Identifier: MIT
// Envelop V2, wNFT implementation
// Powered by OpenZeppelin Contracts 

pragma solidity ^0.8.20;

import "@Uopenzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@Uopenzeppelin/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "./Singleton721.sol";
import "../utils/LibET.sol";
import "../utils/TokenService.sol";
import "../interfaces/IEnvelopV2wNFT.sol";

/**
 * @dev Implementation of WNFT that partial compatible with Envelop V1
 */
contract WNFTLegacy721 is 
    Singleton721, 
    TokenService, 
    IEnvelopV2wNFT,
    ERC721HolderUpgradeable, 
    ERC1155HolderUpgradeable 
{
    string public constant INITIAL_SIGN_STR = 
        "initialize(address,string,string,string,"
          "("
            "((uint8,address),uint256,uint256),"
            "((uint8,address),uint256,uint256)[],"
            "address,"
            "(bytes1,uint256,address)[],"
            "(bytes1,uint256)[],"
            "(address,uint16)[],"
            "bytes2"
          ")"
        ")";
    uint256 public constant ORACLE_TYPE = 2001;
    //string public constant INITIAL_SIGN_STR = "initialize(address,string,string,string)";
    
   
    struct WNFTLegacy721Storage {
        ET.WNFT wnftData;
    }

    error InsufficientCollateral(ET.AssetItem declare, uint256 fact);
    error WnftRuleViolation(bytes2 rule);

    event EtherReceived(
        uint256 indexed balance, 
        uint256 indexed txValue, 
        address indexed txSender
    );

    event EtherBalanceChanged(
        uint256 indexed balanceBefore, 
        uint256 indexed balanceAfter, 
        uint256 indexed txValue, 
        address txSender
    );
    
    // We Use wnft Create event from V1 for seamless integration
    // with Envelop Oracle grabbers. Because this wNFT have same 
    // properties with V1 wNFT
    event WrappedV1(
        address indexed inAssetAddress,
        address indexed outAssetAddress, 
        uint256 indexed inAssetTokenId, 
        uint256 outTokenId,
        address wnftFirstOwner,
        uint256 nativeCollateralAmount,
        bytes2  rules
    );

     /**
     * @dev The contract should be able to receive Eth.
     */
    receive() external payable virtual {
        emit EtherReceived(
            address(this).balance, 
            msg.value,
            msg.sender
        );
    }

    modifier ifUnlocked() {
        _checkLocks();
        _;
    }

    modifier onlyWnftOwner() {
        _wnftOwnerOrApproved(msg.sender);
        _;
    }

    modifier fixEtherBalance() {
        uint256 bb = address(this).balance;
        _;
        _fixEtherChanges(bb, address(this).balance);
    }

    // keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTLegacy721")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant WNFTLegacy721StorageLocation = 0xb25b7d902932741f4867febf64c52dbc3980210eefc4a36bf4280ce48f34a100;

    constructor() {
      _disableInitializers();
      emit EnvelopV2OracleType(ORACLE_TYPE, type(WNFTLegacy721).name);
    }
    function initialize(
        address _creator,
        string memory name_,
        string memory symbol_,
        string memory _tokenUrl,
        ET.WNFT memory _wnftData
        //ET.AssetItem memory _wnftData
    ) public initializer fixEtherBalance()
    {
        
        __WNFTLegacy721_init(name_, symbol_, _creator, _tokenUrl, _wnftData);
    }
        
    ////////////////////////////////////////////////////////////////////////
    // OZ init functions layout                                           //
    ////////////////////////////////////////////////////////////////////////    

    function _getWNFTLegacy721Storage() private pure returns (WNFTLegacy721Storage storage $) {
        assembly {
            $.slot := WNFTLegacy721StorageLocation
        }
    }

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __WNFTLegacy721_init(
        string memory name_, 
        string memory symbol_,
        address _creator,
        string memory _tokenUrl,
        ET.WNFT memory _wnftData
    ) internal onlyInitializing {
        __Singleton721_init(name_, symbol_, _creator, _tokenUrl);
        __WNFTLegacy721_init_unchained(_wnftData, _creator);
    }

    function __WNFTLegacy721_init_unchained(
        ET.WNFT memory _wnftData,
        address _creator
    ) internal onlyInitializing {
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        $.wnftData.inAsset = _wnftData.inAsset;
        $.wnftData.unWrapDestination = _wnftData.unWrapDestination;
        $.wnftData.rules = _wnftData.rules;
        if (_wnftData.locks.length > 0) {
            // TODO Check locks and put to storage
            for (uint256 i = 0; i < _wnftData.locks.length; ++ i) {
                _isValidLockRecord(_wnftData.locks[i]);
                $.wnftData.locks.push(_wnftData.locks[i]);
            }
        }
        if (_wnftData.collateral.length > 0) {
            // TODO Check collateral Balance
            // !!!! Dont save collateral info!!!
             for (uint256 i = 0; i < _wnftData.collateral.length; ++ i) {
                _isValidCollateralRecord(_wnftData.collateral[i]);
                $.wnftData.collateral.push(_wnftData.collateral[i]);
            }
        }
        if (_wnftData.inAsset.asset.assetType != ET.AssetType.EMPTY) {
            // asset that user want to wrap must be transfered to wNFT adddress 
            _isValidCollateralRecord(_wnftData.inAsset);
        }
        
        emit WrappedV1(
            _wnftData.inAsset.asset.contractAddress,
            address(this),
            _wnftData.inAsset.tokenId,
            TOKEN_ID,
            _creator,
            msg.value, //  TODO  Batch??
            _wnftData.rules
        );
    }
    ////////////////////////////////////////////////////////////////////////

    
    function approveHiden(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, _msgSender(), false);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        // Check No Transfer rule
        if (!_checkRule(0x0004, $.wnftData.rules)) {
            revert WnftRuleViolation(0x0004);
        }
        // TODO  deny self address transfer ?????
        super.transferFrom(from, to, tokenId);
    }

    function removeCollateral(ET.AssetItem calldata _collateral, address _to )
        public 
        virtual
        ifUnlocked()
        onlyWnftOwner()
        fixEtherBalance
    {
        _isAbleForRemove(_collateral, msg.sender);

        // transfer method from TokenService
        _transferSafe(_collateral, address(this), _to);
        
    }

    function removeCollateralBatch(ET.AssetItem[] calldata _collateral, address _to ) 
        public
        virtual 
        ifUnlocked()
        onlyWnftOwner()
        fixEtherBalance
    {
            for (uint256 i = 0; i < _collateral.length; ++ i) {
                _isAbleForRemove(_collateral[i], msg.sender);
                // transfer method from TokenService
                _transferSafe(_collateral[i], address(this), _to);    
            } 
    }

    function unWrap(ET.AssetItem[] calldata _collateral) 
        public
        virtual
        ifUnlocked()
        onlyWnftOwner()
        fixEtherBalance
    {
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        // Check No Unwrap rule
        if (!_checkRule(0x0001, $.wnftData.rules)) {
            revert WnftRuleViolation(0x0001);
        }
       
        // Reurns original wrapped asset 
        if ($.wnftData.inAsset.asset.assetType != ET.AssetType.EMPTY) {
            _transferEmergency($.wnftData.inAsset, address(this), msg.sender);    
        }
        
        // TODO  mark inAsset that returned ????
       
       // Returns collatral on demand
        if (_collateral.length > 0) {
            for (uint256 i = 0; i < _collateral.length; ++ i) {
                _transferEmergency(_collateral[i], address(this), msg.sender);    
            } 
        }
        delete $.wnftData;
    }

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
        ifUnlocked()
        onlyWnftOwner()
        fixEtherBalance
        returns (bytes memory r) 
    {
        if (keccak256(_data) == keccak256(bytes(""))) {
            Address.sendValue(payable(_target), _value);
        } else {
            r = Address.functionCallWithValue(_target, _data, _value);
        }
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
        ifUnlocked()
        onlyWnftOwner() 
        fixEtherBalance
        returns (bytes[] memory r) 
    {
    
        r = new bytes[](_dataArray.length);
        for (uint256 i = 0; i < _dataArray.length; ++ i){
            if (keccak256( _dataArray[i]) == keccak256(bytes(""))) {
                Address.sendValue(payable(_targetArray[i]), _valueArray[i]);
            } else {
                r[i] = Address.functionCallWithValue(_targetArray[i], _dataArray[i], _valueArray[i]);
            }
            
        }
    }
    ////////////////////////////////////////////////////////////////////////////
    /////                    GETTERS                                       /////
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual  
        override(ERC721Upgradeable, ERC1155HolderUpgradeable) 
        //override
        returns (bool) 
    {
        //TODO  add current contract interface
       return interfaceId == type(IEnvelopV2wNFT).interfaceId || super.supportsInterface(interfaceId);
    }

    function wnftInfo(uint256 tokenId) external view returns (ET.WNFT memory) {
        tokenId; // suppress solc warn
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        return $.wnftData;
    }

    function tokenURI(uint256 tokenId) public view  override returns (string memory uri_) {
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        uri_ = super.tokenURI(tokenId);

        // V2 wnft RULE for override inAsset URL
        if (_checkRule(0x0100, $.wnftData.rules)) {    
            return uri_;
        } 
        if ($.wnftData.inAsset.asset.assetType == ET.AssetType.ERC721 
            || $.wnftData.inAsset.asset.assetType == ET.AssetType.ERC721
            )
        {
            if (_ownerOf($.wnftData.inAsset) == address(this)) {
                // method from TokenService
                uri_ = _getURI($.wnftData.inAsset);
            }
        }
        
    }
    ////////////////////////////////////////////////////////////////
    //    ******************* internals ***********************   //
    //    ******************* internals ***********************   //
    ////////////////////////////////////////////////////////////////

    function _fixEtherChanges(uint256 _balanceBefore, uint256 _balanceAfter) 
        internal 
    {
        if (_balanceBefore != _balanceAfter) {
            emit EtherBalanceChanged(
               _balanceBefore, 
               _balanceAfter, 
               msg.value, 
               msg.sender
            );
        }
    }

    // 0x00 - TimeLock
    // 0x01 - TransferFeeLock   - UNSUPPORTED IN THIS IMPLEMENATION
    // 0x02 - Personal Collateral count Lock check  - UNSUPPORTED IN THIS IMPLEMENATION
    function _checkLocks() internal virtual {
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        ET.Lock[] memory lck = $.wnftData.locks;
        for (uint256 i = 0; i < lck.length; ++ i) {
            if (lck[i].lockType == 0x00) {
                require(
                    lck[i].param <= block.timestamp,
                    "TimeLock error"
                );
            }
        }
    }
    
    // #### Envelop ProtocolV1 Rules !!! NOT All support in this implementation V2
    // 15   14   13   12   11   10   9   8   7   6   5   4   3   2   1   0  <= Bit number(dec)
    // ------------------------------------------------------------------------------------  
    //  1    1    1    1    1    1   1   1   1   1   1   1   1   1   1   1
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   |   |   |
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   |   |   +-No_Unwrap
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   |   +-No_Wrap 
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   +-No_Transfer
    //  |    |    |    |    |    |   |   |   |   |   |   |   +-No_Collateral
    //  |    |    |    |    |    |   |   |   |   |   |   +-reserved_core
    //  |    |    |    |    |    |   |   |   |   |   +-reserved_core
    //  |    |    |    |    |    |   |   |   |   +-reserved_core  
    //  |    |    |    |    |    |   |   |   +-reserved_core
    //  |    |    |    |    |    |   |   |
    //  |    |    |    |    |    |   |   + - V2. always wnft URL|
    //  +----+----+----+----+----+---+ 
    //      for use in extendings
    /**
     * @dev Use for check rules above.
     */
    function _checkRule(bytes2 _rule, bytes2 _wNFTrules) internal pure virtual returns (bool) {
        return _rule == (_rule & _wNFTrules);
    }

    function _isValidLockRecord(ET.Lock memory _lockRec) internal virtual view {

    }

    function _isValidCollateralRecord(ET.AssetItem memory _collateralRecord) 
        internal 
        virtual
        view 
    {
        uint256 b = _balanceOf(_collateralRecord, address(this));
        if (b < _collateralRecord.amount) {
            revert InsufficientCollateral(_collateralRecord, b);
        }
    }

    function _isAbleForRemove(ET.AssetItem calldata _collateral, address _sender) 
        internal
        virtual
        view
    {
        _sender; //reserved for other implementations
        WNFTLegacy721Storage storage $ = _getWNFTLegacy721Storage();
        ET.AssetItem memory inA = $.wnftData.inAsset;
        uint256 currBalance;
        if (_collateral.asset.assetType == ET.AssetType.NATIVE ||
            _collateral.asset.assetType == ET.AssetType.ERC20  ||
            _collateral.asset.assetType == ET.AssetType.ERC1155
        ) {
            currBalance = _balanceOf(_collateral ,address(this));
            require(currBalance - _collateral.amount >= inA.amount,
                "Not sufficient balance of original wrapped asset"); 
        }  else if (_collateral.asset.assetType == ET.AssetType.ERC721) {
            require(
                _collateral.asset.contractAddress != inA.asset.contractAddress &&
                _collateral.tokenId != inA.tokenId,
                "Can not remove original wrapped asset"
            );
        }
    }
    
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

