// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/utils/Predicter.sol";
import "../../src/interfaces/IPermit2Minimal.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1e27);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockOracle is IEnvelopOracle {
    uint256 public price;

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function getIndexPrice(address) external pure override returns (uint256) {
        return 0;
    }

    function getIndexPrice(CompactAsset[] calldata)
        external
        view
        override
        returns (uint256)
    {
        return price;
    }
}

contract PredicterTest_fork_1 is Test {
    MockERC20 internal token;
    MockOracle internal oracle;
    Predicter internal predicter;

    uint256 public constant userYesPrKey = 0x1bbde125e133d7b485f332b8125b891ea2fbb6a957e758db72e6539d46e2cd71;
    address public constant userYes = 0x7EC0BF0a4D535Ea220c6bD961e352B752906D568;
    address internal creator = address(0xC0FFEE);
    address internal userNo  = address(0xBEEF2);
    address internal feeBeneficiary = address(0xFEEBEEF);
    
    bytes32 public constant DOMAIN_SEPARATOR = 0x866a5aba21966af95d6c7ab78eb2b2fc913915c28be3b9aa07cc04ff903e3f28;
    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    /*function _buildPrediction(uint40 expiration, uint96 strikeAmount, uint96 predictedAmount)
            internal
            view
            returns (Predicter.Prediction memory pred)
    {
        CompactAsset[] memory portfolio = new CompactAsset[](1);
        uint96 portfolioAmount = 1e18;
        portfolio[0] = CompactAsset({token: address(token), amount: portfolioAmount});

        pred.strike = CompactAsset({token: address(token), amount: strikeAmount});
        pred.predictedPrice = CompactAsset({token: address(token), amount: predictedAmount});
        pred.expirationTime = expiration;
        pred.resolvedPrice = 0;
        pred.portfolio = portfolio;
    }*/

    function setUp() public {
        token = new MockERC20();
        oracle = new MockOracle();
        predicter = new Predicter(feeBeneficiary, address(oracle));

        token.mint(userYes, 1_000 ether);
        token.mint(userNo, 1_000 ether);
    }

    /*function getPermitTransferSignature(
        IPermit2.PermitTransferFrom memory permit,
        uint256 privateKey,
        address sender
    ) internal view returns (bytes memory sig) {
        //bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(
                _TOKEN_PERMISSIONS_TYPEHASH,
                permit.permitted.token,
                permit.permitted.amount
            )
        );
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        _PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, sender, permit.nonce, permit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }*/

    function hash(IPermit2.PermitTransferFrom memory permit) internal view returns (bytes32) {
        bytes32 tokenPermissionsHash = _hashTokenPermissions(permit.permitted);
        return keccak256(
            abi.encode(_PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, msg.sender, permit.nonce, permit.deadline)
        );
    }

    function _hashTokenPermissions(IPermit2.TokenPermissions memory permitted)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permitted));
    }

    function _hashTypedData(bytes32 dataHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, dataHash));
    }

    function test_voteWithPermit2_transfersViaPermit2AndMintsShares() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        uint96 strikeAmount = 10 ether;
        uint96 predictedPrice = 100;
        Predicter.Prediction memory pred;

        CompactAsset[] memory portfolio = new CompactAsset[](1);
        portfolio[0] = CompactAsset({token: address(token), amount: 1e18});

        pred.strike = CompactAsset({token: address(token), amount: 10 ether});
        pred.predictedPrice = CompactAsset({token: address(token), amount: 100});
        pred.expirationTime = exp;
        pred.resolvedPrice = 0;
        pred.portfolio = portfolio;

        vm.prank(creator);
        predicter.createPrediction(pred);

        (uint256 yesId, ) = predicter.hlpGet6909Ids(creator);

        // userYes give approve to Permit2 contract
        vm.startPrank(userYes);
        token.approve(predicter.PERMIT2(), 10 ether);

        // Prepare Permit2-structs (this mock not check it)
        IPermit2.PermitTransferFrom memory permit;
        permit.permitted = IPermit2.TokenPermissions({
            token: address(token),
            amount: 10 ether
        });
        permit.nonce = vm.getNonce(userYes);
        permit.deadline = block.timestamp + 1 days;

        IPermit2.SignatureTransferDetails memory transferDetails = IPermit2.SignatureTransferDetails({
            to: address(predicter),
            requestedAmount: 10 ether
        });

        bytes32 hash1 = hash(permit);
        bytes32 hash2 = _hashTypedData(hash1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userYesPrKey, hash2);
        bytes memory signature =  bytes.concat(r, s, bytes1(v));


        //bytes memory signature = getPermitTransferSignature(permit, userYesPrKey, userYes);

        predicter.voteWithPermit2(
            creator,
            true,
            permit,
            transferDetails,
            signature
        );
        vm.stopPrank();

        assertEq(token.balanceOf(address(predicter)), 10 ether);
        assertEq(predicter.balanceOf(userYes, yesId), 10 ether);
    }
}