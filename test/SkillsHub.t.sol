// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,check-send-result,multiple-sends
pragma solidity 0.8.18;

import {CommonTest} from "./helpers/CommonTest.sol";
import {SkillsHub} from "../contracts/skillshub/SkillsHub.sol";
import {OpenBuildToken} from "../contracts/mocks/OpenBuildToken.sol";
import {ISkillsHub} from "../contracts/interfaces/ISkillsHub.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/console.sol";

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

    // function testSetEmploymentConfigSigFailed(uint256 amount) public {
    //     uint256 startTime = block.timestamp;
    //     uint256 endTime = startTime + 1 days;

    //     uint256 deadline = 123;

    //     console.log("TOKEN ADDRESS");
    //     console.logAddress(address(token));

    //     bytes memory signature = sign(amount, address(token), deadline);

    //     vm.assume(amount > 0);

    //     expectEmit(CheckAll);
    //     emit SetEmploymentConfig(1, alice, bob, address(token), amount, startTime, endTime);

    //     vm.prank(alice);
    //     skillsHub.setEmploymentConfig(
    //         bob,
    //         address(token),
    //         amount,
    //         startTime,
    //         endTime,
    //         deadline,
    //         signature
    //     );
    // }

    // Signing function
    function sign(uint256 amount, address token, uint256 deadline) public returns (bytes memory) {
        bytes32 structHash = keccak256(abi.encode(employHash, amount, token, deadline));

        bytes32 digest = ECDSA.toTypedDataHash(employHash, structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);

        bytes memory signature = new bytes(65);

        assembly {
            mstore(add(signature, 32), r)
            mstore(add(signature, 64), s)
            mstore8(add(signature, 96), v)
        }

        return signature;
    }
}
