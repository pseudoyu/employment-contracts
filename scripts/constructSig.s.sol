// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,check-send-result,multiple-sends
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import {SkillsHub} from "../contracts/skillshub/SkillsHub.sol";
import {OpenBuildToken} from "../contracts/mocks/OpenBuildToken.sol";
import {ISkillsHub} from "../contracts/interfaces/ISkillsHub.sol";
import {SigUtils} from "../contracts/signature/SigUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ConstructSigScript is Script {
    function run() public {
        OpenBuildToken token = OpenBuildToken(address(0x521FD468fBba8d929bf22F3031b693A499841E55));
        ISkillsHub skillsHub = ISkillsHub(address(0x6D9964EBe1E9E9e7b45E8A3112a29b82bF9Cc08E));
        // OpenBuildToken token = new OpenBuildToken();
        // ISkillsHub skillsHub = new SkillsHub();

        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                // This should match the domain you set in your client side signing.
                keccak256(bytes("Employment")),
                keccak256(bytes("1")),
                11155111,
                address(skillsHub)
            )
        );

        uint256 amount = 200000000;
        uint256 time = 18000;
        uint256 deadline = 1694763829;

        // setup sigUtils
        SigUtils sigUtils = new SigUtils(DOMAIN_SEPARATOR);

        uint256 invokerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Construct new employment
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount,
            time: time,
            token: address(token),
            deadline: deadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(invokerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        console.logBytes(signature);
    }
}
