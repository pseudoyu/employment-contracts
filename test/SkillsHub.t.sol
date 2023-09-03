// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,check-send-result,multiple-sends
pragma solidity 0.8.18;

import {CommonTest} from "./helpers/CommonTest.sol";
import {SkillsHub} from "../contracts/skillshub/SkillsHub.sol";
import {OpenBuildToken} from "../contracts/mocks/OpenBuildToken.sol";
import {ISkillsHub} from "../contracts/interfaces/ISkillsHub.sol";
import {SigUtils} from "../contracts/signature/SigUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/console.sol";

contract SkillsHubTest is CommonTest {
    uint256 public constant initialBalance = 100 ether;

    bytes32 public DOMAIN_SEPARATOR;

    SigUtils internal sigUtils;

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

        // deploy skillsHub
        skillsHub = new SkillsHub();

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                // This should match the domain you set in your client side signing.
                keccak256(bytes("Employment")),
                keccak256(bytes("1")),
                block.chainid,
                address(skillsHub)
            )
        );

        // setup sigUtils
        sigUtils = new SigUtils(DOMAIN_SEPARATOR);
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

    function testSetEmploymentConfigSig(uint256 amount) public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        uint256 deadline = 123;

        vm.assume(amount > 0);

        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount / (endTime - startTime),
            token: address(token),
            deadline: deadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(employ);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(alice);
        skillsHub.setEmploymentConfig(
            bob,
            address(token),
            amount,
            startTime,
            endTime,
            deadline,
            signature
        );
    }

    function testSetEmploymentConfigSigFailed(uint256 amount) public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        uint256 deadline = 123;

        vm.assume(amount > 0);

        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount / (endTime - startTime),
            token: address(token),
            deadline: deadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(employ);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(SkillsHub__SignerInvalid.selector, address(alice)));
        vm.prank(alice);
        skillsHub.setEmploymentConfig(
            bob,
            address(token),
            amount,
            startTime,
            endTime,
            deadline,
            signature
        );
    }
}
