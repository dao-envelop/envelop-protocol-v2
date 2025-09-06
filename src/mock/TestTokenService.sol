// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

//import {TokenService} from "../TokenService.sol";
import "../utils/TokenService.sol";

contract TestTokenService is TokenService {
    function transferEmergency(ET.AssetItem memory _assetItem, address _from, address _to)
        external
        returns (bytes memory returndata)
    {
        returndata = _transferEmergency(_assetItem, _from, _to);
    }

    function transfer(ET.AssetItem memory _assetItem, address _from, address _to)
        external
        returns (bytes memory returndata)
    {
        returndata = _transfer(_assetItem, _from, _to);
    }

    function transferSafe(ET.AssetItem memory _assetItem, address _from, address _to)
        external
        returns (uint256 _transferedValue)
    {
        _transferedValue = _transferSafe(_assetItem, _from, _to);
    }
}
