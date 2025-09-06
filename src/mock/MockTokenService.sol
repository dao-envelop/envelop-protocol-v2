// SPDX-License-Identifier: MIT
// ENVELOP(NIFTSY) protocol for NFT.
pragma solidity ^0.8.26;

import "./../utils/TokenService.sol";
import "./../utils/LibET.sol";

contract MockTokenService is TokenService {
    function getTransferTxData(ET.AssetItem memory _assetItem, address _from, address _to)
        external
        view
        returns (bytes memory _calldata)
    {
        _calldata = _getTransferTxData(_assetItem, _from, _to);
    }

    function transferEmergency(ET.AssetItem memory _assetItem, address _from, address _to)
        external
        payable
        returns (bytes memory _returndata)
    {
        _returndata = _transferEmergency(_assetItem, _from, _to);
    }

    function transfer(ET.AssetItem memory _assetItem, address _from, address _to)
        external
        payable
        returns (bytes memory _returndata)
    {
        _returndata = _transfer(_assetItem, _from, _to);
    }

    function transferSafe(ET.AssetItem memory _assetItem, address _from, address _to)
        external
        payable
        returns (uint256 _transferedValue)
    {
        _transferedValue = _transferSafe(_assetItem, _from, _to);
    }

    function balanceOf(ET.AssetItem memory _assetItem, address _holder) external view returns (uint256 _balance) {
        _balance = _balanceOf(_assetItem, _holder);
    }

    function ownerOf(ET.AssetItem memory _assetItem) external view returns (address _owner) {
        _owner = _ownerOf(_assetItem);
    }

    function isApprovedFor(ET.AssetItem memory _assetItem, address _owner, address _spender)
        external
        view
        returns (uint256 _approvedBalance)
    {
        _approvedBalance = _isApprovedFor(_assetItem, _owner, _spender);
    }
}
