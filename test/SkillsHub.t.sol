// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,check-send-result,multiple-sends
pragma solidity 0.8.18;

import {CommonTest} from "./helpers/CommonTest.sol";
import {SkillsHub} from "../contracts/skillshub/SkillsHub.sol";
import {OpenBuildToken} from "../contracts/mocks/OpenBuildToken.sol";
import {ISkillsHub} from "../contracts/interfaces/ISkillsHub.sol";

contract SkillsHubTest is CommonTest {
    uint256 public constant initialBalance = 100 ether;

    function setUp() public {
        _setUp();
    }

    function testSetupState() public {
        assertEq(token.name(), "OpenBuildToken");
        assertEq(token.symbol(), "OBT");
    }
}
