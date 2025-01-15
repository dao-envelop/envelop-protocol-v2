// SPDX-License-Identifier: MIT
// Envelop V2, wNFT implementation

pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./Singleton721.sol";
import "../interfaces/IEnvelopV2wNFT.sol";
import "../interfaces/IEnvelopWNFTFactory.sol";
import "./SmartWallet.sol";

/**
 * @dev Native Envelop V2 mplementation of WNFT
 */
contract WNFTV2Envelop721 is 
    Singleton721, 
    SmartWallet,
    IEnvelopV2wNFT
{
    struct InitParams {
        address creator;
        string nftName;
        string nftSymbol;
        string tokenUri;
        address[] addrParams;    // Semantic of this param will defined in exact implemenation 
        bytes32[] hashedParams;  // Semantic of this param will defined in exact implemenation
        uint256[] numberParams;  // Semantic of this param will defined in exact implemenation
        bytes bytesParam;        // Semantic of this param will defined in exact implemenation
    }

    
    struct WNFTV2Envelop721Storage {
        ET.WNFT wnftData;
        mapping(address => uint256) nonceForAddress;
        mapping(address => bool) trustedSigners;
        
    }

    address private immutable __self = address(this);
    address public immutable FACTORY;
    uint256 public constant ORACLE_TYPE = 2002;
    string public constant INITIAL_SIGN_STR = 
        "initialize("
          "(address,string,string,string,address[],bytes32[],uint256[],bytes)"
        ")";
    
    bytes2  public constant SUPPORTED_RULES = 0xffff; // All rules are suupported. But implemented onky No_Transfer
        // #### Envelop ProtocolV1 Rules !!! NOT All support in this implementation V2
    // 15   14   13   12   11   10   9   8   7   6   5   4   3   2   1   0  <= Bit number(dec)
    // ------------------------------------------------------------------------------------  
    //  1    1    1    1    1    1   1   1   1   1   1   1   1   1   1   1
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   |   |   |
    //  |    |    |    |    |    |   |   |   |   |   |   |   |   |   |   +-No_Unwrap (NOT SUPPORTED)
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
    
    // Out main storage because setter not supporrts delegate calls 
    uint256 public nonce; // counter for createWNFTonFactory2

    error WnftRuleViolation(bytes2 rule);
    error RuleSetNotSupported(bytes2 unsupportedRules);
    error NoDelegateCall();
    error UnexpectedSigner(address signer);
  
    event EnvelopWrappedV2(
        address indexed creator, 
        uint256 indexed wnftTokenId, 
        bytes32  indexed rules,
        bytes data
    );
    event EnvelopRulesChanged(
        address indexed wrappedAddress,
        uint256 indexed wrappedId,
        bytes2 newRules
    );

    modifier ifUnlocked() {
        _checkLocks();
        _;
    }

    /**  OZ
     * @dev Check that the execution is not being performed through a delegate call. 
     * This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }


    ///////////////////////////////////////////////////////
    ///                 OZ  Storage pattern              //
    ///////////////////////////////////////////////////////

    // keccak256(abi.encode(uint256(keccak256("envelop.storage.WNFTV2Envelop721")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant WNFTV2Envelop721StorageLocation = 0x058a45f5aef3b02ebbc5c42b328f21f7cf8b0c85eb30c8af8e306a9c50c48100;
    function _getWNFTV2Envelop721Storage() private pure returns (WNFTV2Envelop721Storage storage $) {
        assembly {
            $.slot := WNFTV2Envelop721StorageLocation
        }
    }
    ///////////////////////////////////////////////////////

    constructor(address _defaultFactory) {
        // Zero address for _defaultFactory  is ENABLEd. Because some inheritors
        // would like to switch OFF using `createWNFTonFactory` from  implementation
        FACTORY = _defaultFactory;    
        _disableInitializers();
        emit EnvelopV2OracleType(ORACLE_TYPE, type(WNFTV2Envelop721).name);
    }

    /**  
     * @dev This can be called from anybody  to create proxy for this implementation
     * @param _init  see `struct InitParams` above. This is universal inititialization
     * type for most of Envelop V2 implementations 
     */
    function createWNFTonFactory(InitParams memory _init) 
        public 
        virtual
        notDelegated 
        returns(address wnft) 
    {
        wnft = IEnvelopWNFTFactory(FACTORY).createWNFT(
            address(this), 
            abi.encodeWithSignature(INITIAL_SIGN_STR, _init)
        );
    }

    /**  
     * @dev This can be called from anybody  to create proxy for this implementation
     * in deterministic way. `predictDeterministicAddress` from `EnvelopWNFTFactory`
     * can be used to predict proxy address. 
     * @param _init  see `struct InitParams` above. This is universal inititialization
     * type for most of Envelop V2 implementations 
     */
    function createWNFTonFactory2(InitParams memory _init) 
        public
        virtual 
        notDelegated 
        returns(address wnft) 
    {
        bytes32 salt = keccak256(abi.encode(address(this), ++ nonce));
        wnft = IEnvelopWNFTFactory(FACTORY).createWNFT(
            address(this), 
            abi.encodeWithSignature(INITIAL_SIGN_STR, _init),
            salt
        );
    }

    ////////////////////////////////////////////////////////////////////////
    // OZ init functions layout                                           //
    ////////////////////////////////////////////////////////////////////////  
    // In This implementation next params are supported:
    // WNFTV2Envelop721 hashedParams[0] - rules
    // WNFTV2Envelop721 numberParams[0] - simpleTimeLock
  
    function initialize(
        InitParams calldata _init
    ) public payable virtual initializer 
    {
        __WNFTV2Envelop721_init(_init);
    }
        
    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __WNFTV2Envelop721_init(
          InitParams calldata _init
    ) internal onlyInitializing fixEtherBalance {
        __Singleton721_init(_init.nftName, _init.nftSymbol, _init.creator, _init.tokenUri);
       __WNFTV2Envelop721_init_unchained(_init);
    }

    function __WNFTV2Envelop721_init_unchained(
        InitParams calldata _init
    ) internal onlyInitializing {
        WNFTV2Envelop721Storage storage $ = _getWNFTV2Envelop721Storage();
        if (_init.hashedParams.length > 0 ) {
            _isValidRules(bytes2(_init.hashedParams[0]));
            $.wnftData.rules = bytes2(uint16(uint256(_init.hashedParams[0])));
        }
        
        // Time lock set up
        //_init.numberParams[0] - timestamp for timelock 
        if (_init.numberParams.length  >  0) {
           $.wnftData.locks.push(ET.Lock(0x00, _init.numberParams[0]));
        }
        __WNFTV2Envelop721_init_unchained_posthook(_init, $);
        
    }

    function __WNFTV2Envelop721_init_unchained_posthook(
        InitParams calldata _init,
        WNFTV2Envelop721Storage storage _st
    ) internal virtual {
        emit EnvelopWrappedV2(_init.creator, TOKEN_ID,  _st.wnftData.rules, "");
    } 

    ////////////////////////////////////////////////////////////////////////
    
    /**
     * @dev Variant of `approve` with an optional flag to enable or disable
     *  the {Approval} event. The event is not emitted in the context of transfers.
     */
    function approveHiden(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, _msgSender(), false);
    }

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     * 
     * 
     * This method overrides standart OZ to implement wNFT rules check (NO TRNASFER)
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        WNFTV2Envelop721Storage storage $ = _getWNFTV2Envelop721Storage();
        // Check No Transfer rule
        if (_checkRule(0x0004, $.wnftData.rules)) {
            revert WnftRuleViolation(0x0004);
        }
        // TODO  deny self address transfer ?????
        super.transferFrom(from, to, tokenId);
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
        returns (bytes memory r) 
    {
        r = _executeEncodedTx(_target, _value, _data);
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
        returns (bytes[] memory r) 
    {
    
        r = _executeEncodedTxBatch(_targetArray, _valueArray, _dataArray);
    }

    /**
     * @dev Use this method for interact any dApps onchain
     * @param _target address of dApp smart contract
     * @param _value amount of native token in tx(msg.value)
     * @param _data ABI encoded transaction payload
     * @param _signature only valid signers allowed to be executed
     */
    function executeEncodedTxBySignature(
        address _target,
        uint256 _value,
        bytes memory _data,
        bytes memory _signature
    ) 
        external 
        ifUnlocked()
        returns (bytes memory r) 
    {
        _isValidSigner(_target, _value, _data, _signature);
        _increaseNonce(msg.sender);
        r  = _executeEncodedTx(_target, _value, _data);
        
    }

    /**
     * @dev Use this method for set signers status who can make 
     * sinatures for `executeEncodedTxBySignature`
     * @param _address signer address
     * @param _status signet status to set
     */
    function setSignerStatus(address _address, bool _status) 
        external 
        onlyWnftOwner 
    {
         require(_address != address(0), "No Zero Addresses");
         WNFTV2Envelop721Storage storage $ = _getWNFTV2Envelop721Storage();
         $.trustedSigners[_address] = _status;
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

    /**
     * @dev Returns V1 style wNFT data structures, still used to store some data. 
     * For backward compatibility with some dApps. 
     * @param tokenId is optional because only one NFT exist in V2 contract
     */
    function wnftInfo(uint256 tokenId) public view returns (ET.WNFT memory) {
        tokenId; // suppress solc warn
        WNFTV2Envelop721Storage storage $ = _getWNFTV2Envelop721Storage();
        return $.wnftData;
    }
    
    /**
     * @dev Returns current nonce for address
     * @param _sender address of caller `executeEncodedTxBySignature`
     */
    function getCurrentNonceForAddress(address _sender) external view returns(uint256) {
         return _getCurrentNonce(_sender);
    }

    /**
     * @dev Returns signers status who can make 
     * sinatures for `executeEncodedTxBySignature`
     * @param _signer address of signer
     */
    function getSignerStatus(address _signer) external view returns(bool) {
        return _getSignerStatus(_signer);
    }
    
    /**
     * @dev Returns pure digest, without EIP-191 prefixing.
     * @dev So not forget do prefix + hash befor sign offchain
     * @param _target address which will be called
     * @param _value ethere amount if need fo  tx
     * @param _data encoded tx
     * @param _sender address which would send tx
     */ 
    function getDigestForSign(
        address _target,
        uint256 _value,
        bytes memory _data,
        address _sender
    ) 
        external 
        view 
        returns(bytes32) 
    {
        return _pureDigest(_target, _value, _data, _sender); 
    }

    ////////////////////////////////////////////////////////////////
    //    ******************* internals ***********************   //
    //    ******************* internals ***********************   //
    ////////////////////////////////////////////////////////////////

     function _increaseNonce(address _sender) internal returns(uint256) {
        WNFTV2Envelop721Storage storage $ = _getWNFTV2Envelop721Storage();
        return ++ $.nonceForAddress[_sender];
    }

    // 0x00 - TimeLock
    // 0x01 - TransferFeeLock   - UNSUPPORTED IN THIS IMPLEMENATION
    // 0x02 - Personal Collateral count Lock check  - UNSUPPORTED IN THIS IMPLEMENATION
    function _checkLocks() internal virtual {
        WNFTV2Envelop721Storage storage $ = _getWNFTV2Envelop721Storage();
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
    

    /**
     * @dev Use for check rules above.
     */
    function _checkRule(bytes2 _rule, bytes2 _wNFTrules) internal pure returns (bool isSet) {
        isSet =_rule == (_rule & _wNFTrules);
    }

    function _isValidRules(bytes2 _rules) internal pure virtual returns (bool ok) {
        if (!_checkRule(_rules, SUPPORTED_RULES)) {
            revert RuleSetNotSupported(_rules & SUPPORTED_RULES ^ _rules); //  return 1 in UNsupported digits
        }
        ok = true;

    }

    /**      From OZ
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert NoDelegateCall();
        }
    }

    //////////////////////////////////////////
    ///  Exucute with signature helpers    ///
    //////////////////////////////////////////
    function _getCurrentNonce(address _sender) internal view returns(uint256) {
        WNFTV2Envelop721Storage storage $ = _getWNFTV2Envelop721Storage();
        return $.nonceForAddress[_sender];
    }

    function _getSignerStatus(address _signer) internal view returns(bool) {
        WNFTV2Envelop721Storage storage $ = _getWNFTV2Envelop721Storage();
        return $.trustedSigners[_signer] || _signer == ownerOf(TOKEN_ID);
    }

    function _isValidSigner(
        address _target,
        uint256 _value,
        bytes memory _data,
        bytes memory _signature
    ) 
        internal 
        virtual
        view 
    {   
        (address signer,,) = ECDSA.tryRecover(
            _restoreDigestWasSigned(_target, _value, _data, msg.sender), 
            _signature
        );
       
        if (!_getSignerStatus(signer) ) {
            revert UnexpectedSigner(signer);
        }
    }

    function _restoreDigestWasSigned( 
        address _target,
        uint256 _value,
        bytes memory _data,
        address _sender
    ) 
        internal 
        virtual
        view 
        returns(bytes32 dgst) 
    {
        dgst = MessageHashUtils.toEthSignedMessageHash(
            _pureDigest(_target, _value, _data, _sender)
        );
    }

    function _pureDigest(
        address _target,
        uint256 _value,
        bytes memory _data, 
        address _sender
    )
        internal
        virtual
        view
        returns(bytes32 dgst)
    {
        return keccak256(
            abi.encode(
                block.chainid, _sender, _getCurrentNonce(_sender) + 1,
                _target, _value, _data
            )
        );
    }
}

