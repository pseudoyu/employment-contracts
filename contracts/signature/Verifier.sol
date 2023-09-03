// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import {SigUtils} from "./SigUtils.sol";
import "forge-std/console.sol";

abstract contract Verifier is EIP712 {
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant EMPLOY_HASH =
        keccak256("Employ(uint256 amount,address token,uint256 deadline)");

    SigUtils internal sigUtils;

    constructor() EIP712("Employment", "1") {
        DOMAIN_SEPARATOR = keccak256(
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

        sigUtils = new SigUtils(DOMAIN_SEPARATOR);
    }

    function _recoverEmploy(
        uint256 amount,
        address token,
        uint256 deadline,
        bytes memory signature
    ) internal view returns (address signAddr) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        bytes32 digest = sigUtils.getTypedDataHash(SigUtils.Employ(amount, token, deadline));

        return signAddr = ECDSA.recover(digest, v, r, s);
    }
}
