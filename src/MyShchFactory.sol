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

    address[] public implementations;
    mapping(uint64 tgId => uint256 nonce) public currentNonce;
    mapping(address signer => bool isTrusted) public trustedSigners;

    constructor (address _implementation)
        EnvelopWNFTFactory()
    {
        require(_implementation != address(0), "No zero address");
        implementations.push(_implementation);
    }

    function mintPersonalMSW(uint64 _tgId, address _botWallet, bytes calldata _signature) 
        external 
        returns(address wnft)
    {
        
        // Check signature
        // Encode default initial
        address[] memory _addrParams = new address[](1);
        _addrParams[0] = _botWallet;
        bytes memory initCallData = abi.encodeWithSignature(
            IEnvelopV2wNFT(implementations[implementations.length - 1]).INITIAL_SIGN_STR(),
            InitParams(
                msg.sender, 
                "MyshchWallet", 
                "MSHW", 
                "https://api.envelop.is",  //TODO  change  address
                _addrParams,
                new bytes32[](0),
                new uint256[](0),
                "" 
            )
        );
        wnft = _mintWallet(_tgId, initCallData); 
    }

    function mintBatcMSW() 
        external 
        returns(address[] memory wnfts)
    {

    }

    function newImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), "No zero address");
        implementations.push(_implementation);
    }

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

    function _mintWallet(uint64 _tgId, bytes memory _initCallData) 
        internal 
        returns(address wnft) 
    {
        currentNonce[_tgId] ++;
        address impl  = implementations[implementations.length - 1];
        wnft = _cloneDeterministic(
            impl, 
            _initCallData, 
            keccak256(abi.encode(_tgId, currentNonce[_tgId]))
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

    function _restoreDigest(uint64 _tgId, uint256 _nonce) internal pure returns(bytes32 dgst) {
        dgst = MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encode(_tgId, _nonce)));
    }
}