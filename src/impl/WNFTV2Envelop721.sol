// SPDX-License-Identifier: MIT
// Envelop V2, wNFT implementation

pragma solidity ^0.8.20;

import "./Singleton721.sol";
import "../utils/LibET.sol";
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
    }

    address private immutable __self = address(this);
    address public immutable FACTORY;
    uint256 public constant ORACLE_TYPE = 2002;
    string  public constant INITIAL_SIGN_STR = "initialize(InitParams)";
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
    
   
    //error InsufficientCollateral(ET.AssetItem declare, uint256 fact);
    error WnftRuleViolation(bytes2 rule);
    error RuleSetNotSupported(bytes2 unsupportedRules);
    error NoDelegateCall();

   
  
    event EnvelopWrappedV2(
        address indexed creator, 
        uint256 indexed wnftTkenId, 
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
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
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
        require(_defaultFactory != address(0), "No Zero Factoties");
        FACTORY = _defaultFactory;    
        _disableInitializers();
        emit EnvelopV2OracleType(ORACLE_TYPE, type(WNFTV2Envelop721).name);
    }

    function createWNFTonFactory(InitParams calldata _init) 
        external 
        notDelegated 
        returns(address wnft) 
    {
        wnft = IEnvelopWNFTFactory(FACTORY).createWNFT(
            address(this), 
            abi.encodeWithSignature(INITIAL_SIGN_STR, _init)
        );
    }

    ////////////////////////////////////////////////////////////////////////
    // OZ init functions layout                                           //
    ////////////////////////////////////////////////////////////////////////    
    function initialize(
        InitParams calldata _init
    ) public virtual initializer 
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
        __WNFTLegacy721_init_unchained(_init);
    }

    function __WNFTLegacy721_init_unchained(
        InitParams calldata _init
    ) internal onlyInitializing {
        WNFTV2Envelop721Storage storage $ = _getWNFTV2Envelop721Storage();
        if (bytes2(_init.hashedParams[0]) != 0x0000) {
            _isValidRules(bytes2(_init.hashedParams[0]));
            $.wnftData.rules = bytes2(_init.hashedParams[0]);
        }
        
        if (_init.numberParams[0] > 0) {
           $.wnftData.locks.push(ET.Lock(0x00, _init.numberParams[0]));
        }
        emit EnvelopWrappedV2(_init.creator, TOKEN_ID, _init.hashedParams[0], "");
    }
    ////////////////////////////////////////////////////////////////////////
    

    function approveHiden(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, _msgSender(), false);
    }

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
        ifUnlocked()
        onlyWnftOwner() 
        returns (bytes[] memory r) 
    {
    
        r = super._executeEncodedTxBatch(_targetArray, _valueArray, _dataArray);
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

    function wnftInfo(uint256 tokenId) external view returns (ET.WNFT memory) {
        tokenId; // suppress solc warn
        WNFTV2Envelop721Storage storage $ = _getWNFTV2Envelop721Storage();
        return $.wnftData;
    }

   
    ////////////////////////////////////////////////////////////////
    //    ******************* internals ***********************   //
    //    ******************* internals ***********************   //
    ////////////////////////////////////////////////////////////////

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

    
    
}

