// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

abstract contract Verifier is EIP712 {
    bytes32 public domainSeparator;
    bytes32 public constant employHash =
        keccak256("Employ(uint256 amount,address token,uint256 deadline)");

    constructor() EIP712("Employment", "1") {
        domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                // This should match the domain you set in your client side signing.
                keccak256(bytes("Employment")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function _recoverEmploy(
        uint256 amount,
        address token,
        uint256 deadline,
        bytes memory signature
    ) internal pure returns (address signAddr) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        bytes32 structHash = keccak256(abi.encode(employHash, amount, token, deadline));
        return _recoverVerify(structHash, v, r, s);
    }

    function _recoverVerify(
        bytes32 structHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address signAddr) {
        bytes32 digest = ECDSA.toTypedDataHash(employHash, structHash);
        signAddr = ECDSA.recover(digest, v, r, s);
    }
}
