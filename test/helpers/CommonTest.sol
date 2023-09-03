// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.18;

import {OpenBuildToken} from "../../contracts/mocks/OpenBuildToken.sol";
import {SkillsHub} from "../../contracts/skillshub/SkillsHub.sol";
import {Utils} from "./Utils.sol";
import {SigUtils} from "../../contracts/signature/SigUtils.sol";

contract CommonTest is Utils {
    OpenBuildToken public token;
    SkillsHub public skillsHub;

    address public constant admin = address(0x999999999999999999999999999999);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant alicePrivateKey = 0x1111;
    uint256 public constant bobPrivateKey = 0x2222;
    uint256 public constant carolPrivateKey = 0x3333;
    uint256 public constant dickPrivateKey = 0x4444;
    uint256 public constant erikPrivateKey = 0x5555;

    address public alice = vm.addr(alicePrivateKey);
    address public bob = vm.addr(bobPrivateKey);
    address public carol = vm.addr(carolPrivateKey);
    address public dick = vm.addr(dickPrivateKey);
    address public erik = vm.addr(erikPrivateKey);

    function _setUp() internal {
        // deploy web3Entry related contracts
        _deployContracts();
    }

    function _deployContracts() internal {
        // deploy token
        token = new OpenBuildToken();
    }
}
