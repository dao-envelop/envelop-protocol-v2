// SPDX-License-Identifier: MIT
// Myshch Factory for Envelop wNFT contracts
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./EnvelopWNFTFactory.sol";

contract MyShchFactory is EnvelopWNFTFactory {

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

    address[] public implementations;
    mapping(uint64 tgId => uint256 nonce) public currentNonce;
    mapping(address signer => Signer) public trustedSigners;

    error OneBotPerSigner(address signer, uint64 botId);
    error UnexpectedSigner(address signer);

    constructor (address _implementation)
        EnvelopWNFTFactory()
    {
        require(_implementation != address(0), "No zero address");
        implementations.push(_implementation);
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
            } else {
                revert OneBotPerSigner(msg.sender, s.botId);
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
            IEnvelopV2wNFT(implementations[implementations.length - 1]).INITIAL_SIGN_STR(),
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

    function mintBatcMSW(
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
            IEnvelopV2wNFT(implementations[implementations.length - 1]).INITIAL_SIGN_STR(),
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
    ///////////////////////////////////////////////
    /// Admins functions                      /////
    ///////////////////////////////////////////////
    function newImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), "No zero address");
        implementations.push(_implementation);
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

    function getImplementationHistory() external view returns(address[] memory) {
        return implementations;
    }

    function getDigestForSign(uint64 _tgId, uint256 _nonce) 
        external 
        pure 
        returns(bytes32) 
    {
         return _restoreDigest(_tgId, _nonce); 
    }

    ///////////////////////////////////////////////
    //////   Internals                    /////////
    ///////////////////////////////////////////////
    function _mintWallet(uint64 _tgId, bytes memory _initCallData, uint256 _valueDenominator) 
        internal 
        returns(address wnft) 
    {
        currentNonce[_tgId] ++;
        address impl  = implementations[implementations.length - 1];
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
            implementations[implementations.length - 1], // implementation address
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
        pure 
        returns(bytes32 dgst) 
    {
        dgst = MessageHashUtils.toEthSignedMessageHash(
            keccak256(
                abi.encode(_tgId, _nonce)
            )
        );
    }
}