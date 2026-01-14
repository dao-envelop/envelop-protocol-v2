// SPDX-License-Identifier: MIT
// ENVELOP(NIFTSY) protocol V2 for NFT .
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../utils/LibET.sol";

interface IEnvelopV2wNFT is IERC165 {
    event EnvelopV2OracleType(uint256 indexed oracleType, string contractName);

    function FACTORY() external view returns (address);
    function INITIAL_SIGN_STR() external view returns (string memory);
    function ORACLE_TYPE() external view returns (uint256);
    function SUPPORTED_RULES() external pure returns (bytes2);

    /**
     * @dev Use this method for interact any dApps onchain
     * @param _target address of dApp smart contract
     * @param _value amount of native token in tx(msg.value)
     * @param _data ABI encoded transaction payload
     */
    function executeEncodedTx(address _target, uint256 _value, bytes memory _data) external returns (bytes memory r);

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
    ) external returns (bytes[] memory r);

    /**
     * @dev Returns V1 style wNFT data structures, still used to store some data.
     * For backward compatibility with some dApps.
     * @param tokenId is optional because only one NFT exist in V2 contract
     */
    function wnftInfo(uint256 tokenId) external view returns (ET.WNFT memory);

    /*function executeEncodedTxBySignature(
        address _target,
        uint256 _value,
        bytes memory _data,
        bytes memory _signature
    )
        external
        returns (bytes memory r); */
}
