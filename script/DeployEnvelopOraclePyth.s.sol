// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {EnvelopOraclePyth} from "../src/utils/EnvelopOraclePyth.sol";

/// @notice Deploys EnvelopOraclePyth on Ethereum mainnet wired to the live Pyth contract,
///         then preseeds the 35 ERC20 → Pyth feedId pairs covering chainId 1 index templates
///         in indexpage-sdk/src/index_templates.json (ETHx and SPECTRA are deferred to v2).
contract DeployEnvelopOraclePyth_Eth is Script {
    // Pyth contract on Ethereum mainnet.
    address public constant PYTH_ETH = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;

    // Multisig / future owner of the oracle. Set to address(0) to keep deployer as owner.
    address public constant NEW_OWNER = 0x5992Fe461F81C8E0aFFA95b831E50e9b3854BA0E;

    // ETH sentinel address (must match EnvelopOraclePyth.ETH_BASE).
    address public constant ETH_BASE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function run() external {
        require(block.chainid == 1, "DeployEnvelopOraclePyth_Eth: only mainnet");

        vm.startBroadcast();

        EnvelopOraclePyth oracle = new EnvelopOraclePyth(PYTH_ETH, 3600);

        (address[] memory tokens, bytes32[] memory feeds) = _v1FeedMap();
        oracle.setFeedIdBatch(tokens, feeds);

        if (NEW_OWNER != address(0)) {
            oracle.transferOwnership(NEW_OWNER);
        }

        console2.log("EnvelopOraclePyth deployed at:", address(oracle));
        console2.log("Pyth contract:               ", PYTH_ETH);
        console2.log("MAX_STALE (s):                ", uint256(3600));
        console2.log("Feeds preset:                ", tokens.length);

        vm.stopBroadcast();
    }

    /// @dev 35 token → Pyth feedId pairs covered by v1 (full table in
    ///      `codex/tasks/task_006.md`). ETHx and SPECTRA are intentionally omitted.
    function _v1FeedMap()
        internal
        pure
        returns (address[] memory tokens, bytes32[] memory feeds)
    {
        tokens = new address[](35);
        feeds  = new bytes32[](35);

        tokens[0]  = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32; // LDO
        feeds[0]   = 0xc63e2a7f37a04e5e614c07238bedb25dcc38927fba8fe890597a593c0b2fa4ad;

        tokens[1]  = 0x01791F726B4103694969820be083196cC7c045fF; // ETHFI
        feeds[1]   = 0xb27578a9654246cb0a2950842b92330e9ace141c52b63829cc72d5c45a5a595a;

        tokens[2]  = 0x57e114B691Db790C35207b2e685D4A43181e6061; // ENA
        feeds[2]   = 0xb7910ba7322db020416fcac28b48c01212fd9cc8fbcbaf7d30477ed8605f6bd4;

        tokens[3]  = 0x56072C95FAA701256059aa122697B133aDEd9279; // SKY
        feeds[3]   = 0xa483243eed64ca27a1f6e26385b7d1e0d07e9fe264bb6903efb3efc4689d3fe7;

        tokens[4]  = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9; // AAVE
        feeds[4]   = 0x2b9ab1e972a281585084148ba1389800799bd4be63b957507db1349314e47445;

        tokens[5]  = 0x58D97B57BB95320F9a05dC918Aef65434969c2B2; // MORPHO
        feeds[5]   = 0x5b2a4c542d4a74dd11784079ef337c0403685e3114ba0d9909b5c7a7e06fdc42;

        tokens[6]  = 0x643C4E15d7d62Ad0aBeC4a9BD4b001aA3Ef52d66; // SYRUP
        feeds[6]   = 0xed86e0c6321d790302e5d88751995ebc9079273e549005d68a83ba72e48ff1ce;

        tokens[7]  = 0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b; // EUL
        feeds[7]   = 0xa7adc417fe7e862494b488e89d88ab23f468661b63542d8f719da8f77e34c51f;

        tokens[8]  = 0xc20059e0317DE91738d13af027DfC4a50781b066; // SPK
        feeds[8]   = 0x88a17f294aa817de3f22d5b1ebf2b4e5979e252264085f875eb9849eefeb718d;

        tokens[9]  = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984; // UNI
        feeds[9]   = 0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501;

        tokens[10] = 0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898; // CAKE
        feeds[10]  = 0x2356af9529a1064d41e32d617e2ce1dca5733afa901daba9e2b68dee5d53ecf9;

        tokens[11] = 0x232CE3bd40fCd6f80f3d55A522d03f25Df784Ee2; // LIT (Lighter)
        feeds[11]  = 0xc0c83f00c39165892d55dcd17ade2191e289697e2ac132d9ab721e20834e2a9e;

        tokens[12] = 0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb; // FLUID
        feeds[12]  = 0x47d462d8bac4c29b6ae1792029b9b92c8adea12ed22155bfc22f481287f1e349;

        tokens[13] = 0x4B1E80cAC91e2216EEb63e29B957eB91Ae9C2Be8; // CRV
        feeds[13]  = 0xa19d04ac696c7a6616d291c7e5d1377cc8be437c327b75adb5dc1bad745fcae8;

        tokens[14] = 0x808507121B80c02388fAd14726482e061B8da827; // PENDLE
        feeds[14]  = 0x9a4df90b25497f66b1afb012467e316e801ca3d839456db028892fe8c70c8016;

        tokens[15] = 0x455e53CBB86018Ac2B8092FdCd39d8444aFFC3F6; // POL
        feeds[15]  = 0xffd11c5a1cfd42f80afb2df4d9f264c15f956d68153335374ec10722edd70472;

        tokens[16] = 0xB50721BCf8d664c30412Cfbc6cf7a15145234ad1; // ARB
        feeds[16]  = 0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5;

        tokens[17] = 0xCa14007Eff0dB1f8135f4C25B34De49AB0d42766; // STRK
        feeds[17]  = 0x6a182399ff70ccf3e06024898942028204125a819e519a335ffa4579e66cd870;

        tokens[18] = 0xF57e7e7C23978C3cAEC3C3548E3D615c346e79fF; // IMX
        feeds[18]  = 0x941320a8989414874de5aa2fc340a75d5ed91fdff1613dd55f83844d52ea63a2;

        tokens[19] = 0x514910771AF9Ca656af840dff83E8264EcF986CA; // LINK
        feeds[19]  = 0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221;

        tokens[20] = 0x6985884C4392D348587B19cb9eAAf157F13271cd; // ZRO (LayerZero)
        feeds[20]  = 0x3bd860bea28bf982fa06bcf358118064bb114086cc03993bd76197eaab0b8018;

        tokens[21] = 0x77E06c9eCCf2E797fd462A92B6D7642EF85b0A44; // NEAR
        feeds[21]  = 0xc415de8d2eba7db216527dff4b60e8f3a5311c740dadb233e13e12547e226750;

        tokens[22] = 0xbe0Ed4138121EcFC5c0E56B40517da27E6c5226B; // ATH (Aethir)
        feeds[22]  = 0xf6b551a947e7990089e2d5149b1e44b369fcc6ad3627cb822362a2b19d24ad4a;

        tokens[23] = 0x44ff8620b8cA30902395A7bD3F2407e1A091BF73; // RENDER
        feeds[23]  = 0x3d4a2bd9535be6ce8059d75eadeba507b043257321aa544717c56fa19b49e35d;

        tokens[24] = 0x85F17Cf997934a597031b2E18a9aB6ebD4B9f6a4; // TAO (wTAO)
        feeds[24]  = 0x410f41de235f2db824e562ea7ab2d3d3d4ff048316c61d629c0b93f58584e1af;

        tokens[25] = 0xfAbA6f8e4a5E8Ab82F62fe7C39859FA577269BE3; // ONDO
        feeds[25]  = 0xd40472610abe56d36d065a0cf889fc8f1dd9f3b7f2a478231a5fc6df07ea5ce3;

        tokens[26] = 0x3632DEa96A953C11dac2f00b4A05a32CD1063fAE; // CRCLon (Equity)
        feeds[26]  = 0x92b8527aabe59ea2b12230f7b532769b133ffb118dfbd48ff676f14b273f1365;

        tokens[27] = 0xFeDC5f4a6c38211c1338aa411018DFAf26612c08; // SPYon (Equity)
        feeds[27]  = 0x19e09bb805456ada3979a7d1cbb4b6d63babc3a0f8e8a9509f68afa5c4c11cd5;

        tokens[28] = 0x2D1F7226Bd1F780AF6B9A49DCC0aE00E8Df4bDEE; // NVDAon (Equity)
        feeds[28]  = 0xb1073854ed24cbc755dc527418f52b7d271f6cc967bbf8d8129112b18860a593;

        tokens[29] = 0x68749665FF8D2d112Fa859AA293F07A622782F38; // XAUT
        feeds[29]  = 0x44465e17d2e9d390e70c999d5a11fda4f092847fcd2e3e5aa089d96c98a30e67;

        tokens[30] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC
        feeds[30]  = 0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33;

        tokens[31] = ETH_BASE;                                   // ETH (native sentinel)
        feeds[31]  = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

        tokens[32] = 0xB8c77482e45F1F44dE1745F52C74426C631bDD52; // BNB
        feeds[32]  = 0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f;

        tokens[33] = 0x50327c6c5a14DCaDE707ABad2E27eB517df87AB5; // TRX
        feeds[33]  = 0x67aed5a24fdad045475e7195c98a98aea119c763f272d4523f5bac93a4f33c2b;

        tokens[34] = 0x4A64515E5E1d1073e83f30cB97BEd20400b66E10; // WZEC (via ZEC/USD)
        feeds[34]  = 0xbe9b59d178f0d6a97ab4c343bff2aa69caa1eaae3e9048a65788c529b125bb24;
        
        // --edit manually after researc
        tokens[35] = 0xFe0c30065B384F05761f15d0CC899D4F9F9Cc0eB; // ETHFI
        feeds[35]  = 0xb27578a9654246cb0a2950842b92330e9ace141c52b63829cc72d5c45a5a595a;

        tokens[36] = 0x6fB3e0A217407EFFf7Ca062D46c26E5d60a14d69; // IOTX 
        feeds[36]  = 0xa83103141916013b5679001e273281303a6c05f4cebd94da00a785bd74d1e6d8;

        tokens[37] = 0x6e1A19F235bE7ED8E3369eF73b196C07257494DE; // WFIL 
        feeds[37]  = 0x150ac9b959aee0051e4091f0ef5216d941f590e1c5e7f91cf7635b5c11628c0e;

        tokens[38] = 0xF042cfa86cf1D598a75Bdb55c3507a1F39f9493b; // COINon 
        feeds[38]  = 0x42ded7a3ed036606ab22ece1c942f6f9245a67f6f4ec27cfad5974d45fe9d6b6;

        tokens[39] = 0x0e397938C1Aa0680954093495B70A9F5e2249aBa; // QQQon 
        feeds[39]  = 0x9695e2b96ea7b3859da9ed25b7a46a920a776e2fdae19a7bcfdf2b219230452d;

        tokens[40] = 0xbA47214eDd2bb43099611b208f75E4b42FDcfEDc; // GOOGLon 
        feeds[40]  = 0x07d24bb76843496a45bce0add8b51555f2ea02098cb04f4c6d61f7b5720836b4;

    }
}
