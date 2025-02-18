// SPDX-License-Identifier: MIT
// Myshch Factory for Envelop wNFT contracts
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./EnvelopWNFTFactory.sol";

contract MyShchFactory is EnvelopWNFTFactory {
    
    enum AssetType {EMPTY, NATIVE, ERC20, ERC721, ERC1155, FUTURE1, FUTURE2, FUTURE3}

    struct InitDistributtion {
        address receiver;
        uint256 amount;
    }

    // TODO  think about move to V2 Interface
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

    struct Signer {
        bool isTrusted;
        uint64 botId;
    }

    //address[] public implementations;
    mapping(AssetType => address[]) public implementations;
    mapping(uint64 tgId => uint256 nonce) public currentNonce;
    mapping(address signer => Signer) public trustedSigners;

    error OneBotPerSigner(address signer, uint64 botId);
    error UnexpectedSigner(address signer);

    constructor (address _implementation)
        EnvelopWNFTFactory()
    {
        require(_implementation != address(0), "No zero address");
        implementations[AssetType.ERC721].push(_implementation);
    }

    function mintPersonalMSW(uint64 _tgId, bytes calldata _signature) 
        external 
        payable
        returns(address wnft)
    {
        address[] memory addrParams;
        bytes32[] memory hashedParams;
        Signer memory s = trustedSigners[msg.sender];
        // Check signature
        // No need check signature if signer mint for yourself
        if (s.isTrusted) {
            // Only one bot for one EOA
            if (s.botId == 0){
                trustedSigners[msg.sender].botId = _tgId;
            } 
            // prepare wNFT init params. This will be sbt, no default relayer
            hashedParams = new bytes32[](1);
            addrParams = new address[](0);
            hashedParams[0] = bytes32(abi.encode(4));
        } else {
            s = _isTrustedSigner(
                _restoreDigest(_tgId, currentNonce[_tgId] + 1), 
                _signature
            );

            // prepare wNFT init params. Default relayer
            hashedParams = new bytes32[](0);
            addrParams = new address[](1);
            addrParams[0] =  _getAddressForNonce(s.botId, currentNonce[s.botId]);
        }    

        // Encode default initial
        bytes memory initCallData = abi.encodeWithSignature(
            IEnvelopV2wNFT(
                implementations[AssetType.ERC721][implementations[AssetType.ERC721].length - 1]
            ).INITIAL_SIGN_STR(),
            InitParams(
                msg.sender, 
                "MyshchWallet", 
                "MSHW", 
                "https://api.envelop.is",  //TODO  change  address
                addrParams,
                hashedParams,
                new uint256[](0),
                "" 
            )
        );
        wnft = _mintWallet(_tgId, initCallData, 1); 
        //Address.sendValue(payable(wnft), msg.value);
    }

    function mintBatchMSW(
        uint64[] calldata _tgIds, 
        address[] memory _receivers, 
        bytes calldata _signature
    )  
        external 
        payable
        returns(address[] memory wnfts)
    {
        Signer memory s = _isTrustedSigner(
            // TODO  add salt
            keccak256(abi.encode(msg.sender)), 
            _signature
        );
        wnfts = new address[](_tgIds.length);
        address[] memory addrParams = new address[](1);
        bytes32[] memory hashedParams = new bytes32[](0);
        addrParams[0] =  _getAddressForNonce(s.botId, currentNonce[s.botId]);
        for (uint256 i = 0; i < _tgIds.length; i++) {
            // Prepare initializing
            bytes memory initCallData = abi.encodeWithSignature(
            IEnvelopV2wNFT(
                implementations[AssetType.ERC721][implementations[AssetType.ERC721].length - 1]
            ).INITIAL_SIGN_STR(),
            InitParams(
                _receivers[i], 
                "MyshchWallet", 
                "MSHW", 
                "https://api.envelop.is",  //TODO  change  address
                addrParams,
                hashedParams,
                new uint256[](0),
                "" 
            )
        );
            address wnft = _mintWallet(_tgIds[i], initCallData, _tgIds.length);
            wnfts[i] = wnft;

            //Address.sendValue(payable(wnft), msg.value/_tgIds.length); 
        }

    }

    function createCustomERC20(
        address _creator,
        string memory name_,
        string memory symbol_,
        uint256 _totalSupply,
        InitDistributtion[] memory _initialHolders
    ) external returns(address erc20) {
        
        address erc20impl =  implementations[AssetType.ERC20][implementations[AssetType.ERC20].length - 1];
        // Encode default initial
        bytes memory initCallData = abi.encodeWithSignature(
            // We can use this interface because erc20 implementation has same method
            IEnvelopV2wNFT(
                erc20impl
            ).INITIAL_SIGN_STR(),
            _creator, name_, symbol_, _totalSupply, _initialHolders
        );

        erc20 = _clone(erc20impl, initCallData);
    }
    ///////////////////////////////////////////////
    /// Admins functions                      /////
    ///////////////////////////////////////////////
    function newImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), "No zero address");
        implementations[AssetType.ERC721].push(_implementation);
    }
    
    function newImplementation(AssetType _type, address _implementation) external onlyOwner {
        require(_implementation != address(0), "No zero address");
        implementations[_type].push(_implementation);
    }
    function setSignerStatus(address _signer, bool _status) external onlyOwner {
        require(_signer != address(0), "No zero address");
        trustedSigners[_signer].isTrusted = _status;
    }
    ///////////////////////////////////////////////
    function getCurrentAddress(uint64 _tgId) external view returns(address wnft) {
        if (currentNonce[_tgId] == 0){
            wnft = address(0);
            return wnft;
        }
        wnft = _getAddressForNonce( _tgId, currentNonce[_tgId]);
    }

    function getAddressForNonce(uint64 _tgId, uint256 _nonce) 
        external 
        view 
        returns(address wnft) 
    {
        wnft = _getAddressForNonce( _tgId, _nonce);
    }

    function getImplementationHistory(AssetType _type) external view returns(address[] memory) {
        return implementations[_type];
    }

    function getImplementationHistory() external view returns(address[] memory) {
        return implementations[AssetType.ERC721];
    }
    
    /**
     * @dev Returns pure digest, without EIP-191 prefixing.
     * @dev So not forget do prefix + hash befor sign offchain
     * @param _tgId unic external identifier
     * @param _nonce incrementing value for obtain digest for next mint
     */ 
    function getDigestForSign(uint64 _tgId, uint256 _nonce) 
        external 
        view 
        returns(bytes32) 
    {
        return keccak256(abi.encode(_tgId, _nonce, block.chainid)); 
    }

    ///////////////////////////////////////////////
    //////   Internals                    /////////
    ///////////////////////////////////////////////
    function _mintWallet(uint64 _tgId, bytes memory _initCallData, uint256 _valueDenominator) 
        internal 
        returns(address wnft) 
    {
        currentNonce[_tgId] ++;
        address impl  = implementations[AssetType.ERC721][implementations[AssetType.ERC721].length - 1];
        wnft = _cloneDeterministic(
            impl, 
            _initCallData, 
            keccak256(abi.encode(_tgId, currentNonce[_tgId])),
            _valueDenominator
        );

        emit EnvelopV2Deployment(
            wnft, 
            impl,
            IEnvelopV2wNFT(impl).ORACLE_TYPE()
        );
    }

    function _getAddressForNonce(uint64 _tgId, uint256 _nonce) 
        internal 
        view 
        returns(address)
    {
        return predictDeterministicAddress(
            implementations[AssetType.ERC721][implementations[AssetType.ERC721].length - 1], // implementation address
            keccak256(abi.encode(_tgId, _nonce))
        );
    }

    function _isTrustedSigner(bytes32 _digest, bytes calldata _signature) 
        internal 
        view 
        returns(Signer memory s) 
    {
        (address signer,,) = ECDSA.tryRecover(
            _digest, 
            _signature
        );
        s = trustedSigners[signer];
        if (!s.isTrusted) {
            revert UnexpectedSigner(signer);
        }
    }

    function _restoreDigest(uint64 _tgId, uint256 _nonce) 
        internal 
        view 
        returns(bytes32 dgst) 
    {
        dgst = MessageHashUtils.toEthSignedMessageHash(
            keccak256(
                abi.encode(_tgId, _nonce, block.chainid)
            )
        );
    }
}