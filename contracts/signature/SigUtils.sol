// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract SigUtils {
    struct Employ {
        uint256 amount;
        address token;
        uint256 deadline;
    }

    bytes32 internal DOMAIN_SEPARATOR;

    bytes32 public constant EMPLOY_HASH =
        keccak256("Employ(uint256 amount,address token,uint256 deadline)");

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    // computes the hash of a employ
    function getStructHash(Employ memory _employ) public pure returns (bytes32) {
        return keccak256(abi.encode(EMPLOY_HASH, _employ.amount, _employ.token, _employ.deadline));
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Employ memory _employ) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_employ)));
    }
}
