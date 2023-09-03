// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,check-send-result,multiple-sends
pragma solidity 0.8.18;

import {CommonTest} from "./helpers/CommonTest.sol";
import {SkillsHub} from "../contracts/skillshub/SkillsHub.sol";
import {OpenBuildToken} from "../contracts/mocks/OpenBuildToken.sol";
import {ISkillsHub} from "../contracts/interfaces/ISkillsHub.sol";

contract SkillsHubTest is CommonTest {
    uint256 public constant initialBalance = 100 ether;

    // events
    event SetEmploymentConfig(
        uint256 indexed employmentConfigId,
        address indexed employerAddress,
        address indexed developerAddress,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime
    );

    event RenewalEmploymentConfig(
        uint256 indexed employmentConfigId,
        address indexed employerAddress,
        address indexed developerAddress,
        address token,
        uint256 amount,
        uint256 additonalAmount,
        uint256 startTime,
        uint256 endTime
    );

    event ClaimSalary(
        uint256 indexed employmentConfigId,
        address token,
        uint256 claimAmount,
        uint256 lastClaimedTime
    );

    event CancelEmployment(
        uint256 indexed employmentConfigId,
        address token,
        uint256 refundedAmount
    );

    // custom errors
    error SkillsHub__SignerInvalid(address signer);
    error SkillsHub__EmploymentConfigIdInvalid(uint256 employmentConfigId);
    error SkillsHub__EmploymentTimeInvalid(uint256 startTime, uint256 endTime);
    error SkillsHub__RenewalTimeInvalid(uint256 endTime, uint256 renewalTime);
    error SkillsHub__ConfigAmountInvalid(uint256 amount);
    error SkillsHub__FractionOutOfRange(uint256 fraction);
    error SkillsHub__RenewalEmployerInconsistent(address employer);
    error SkillsHub__RenewalEmploymentAlreadyEnded(uint256 endTime, uint256 renewalTime);
    error SkillsHub__CancelEmployerInconsistent(address employer);
    error SkillsHub__ClaimSallaryDeveloperInconsistent(address developer);
    error SkillsHub__EmploymentNotStarted(uint256 startTime, uint256 claimTime);

    function setUp() public {
        _setUp();
    }

    function testSetupState() public {
        assertEq(token.name(), "OpenBuildToken");
        assertEq(token.symbol(), "OBT");
    }

    function testSetFraction(uint256 fraction) public {
        vm.assume(fraction <= 10000);

        vm.startPrank(alice);
        skillsHub.setFeeFraction(alice, fraction);

        assertEq(skillsHub.getFeeFraction(alice), fraction);
    }

    function testSetFractionFailed(uint256 fraction) public {
        vm.assume(fraction > 10000);

        vm.expectRevert(
            abi.encodeWithSelector(SkillsHub__FractionOutOfRange.selector, uint256(fraction))
        );
        vm.startPrank(alice);
        skillsHub.setFeeFraction(alice, fraction);

        assertEq(skillsHub.getFeeFraction(alice), 0);
    }
}
