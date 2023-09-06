// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,check-send-result,multiple-sends
pragma solidity 0.8.18;

import {CommonTest} from "./helpers/CommonTest.sol";
import {SkillsHub} from "../contracts/skillshub/SkillsHub.sol";
import {OpenBuildToken} from "../contracts/mocks/OpenBuildToken.sol";
import {ISkillsHub} from "../contracts/interfaces/ISkillsHub.sol";
import {SigUtils} from "../contracts/signature/SigUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

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
        address indexed token,
        uint256 indexed claimAmount,
        uint256 lastClaimedTime
    );

    event CancelEmployment(
        uint256 indexed employmentConfigId,
        address indexed token,
        uint256 indexed refundedAmount
    );

    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

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
    error SkillsHub__SignatureExpire(uint256 deadline, uint256 currentTime);

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

    function testSetEmploymentConfig(uint256 amount) public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        uint256 deadline = startTime + 2 days;

        // get random employment amount
        vm.assume(amount > 0 && amount <= 10);

        // transfer token
        token.transfer(address(alice), amount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount / (endTime - startTime),
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        expectEmit(CheckAll);
        emit Approval(address(alice), address(skillsHub), 0);

        expectEmit(CheckAll);
        emit Transfer(address(alice), address(skillsHub), amount);

        expectEmit(CheckAll);
        emit SetEmploymentConfig(
            1,
            address(alice),
            address(bob),
            address(token),
            amount,
            startTime,
            endTime
        );

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

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(skillsHub)), amount);
    }

    function testSetEmploymentConfigInsufficientAllowance(uint256 amount) public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        uint256 deadline = startTime + 2 days;

        // get random employment amount
        vm.assume(amount > 0 && amount <= 10);

        // transfer token
        token.transfer(address(alice), amount);

        // construct signature(signer: developer(bob))
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

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(skillsHub)), 0);
    }

    function testSetEmploymentConfigInsufficientBalance(uint256 amount) public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        uint256 deadline = startTime + 2 days;

        // get random employment amount
        vm.assume(amount > 2 && amount <= 10);

        // transfer token
        token.transfer(address(alice), amount - 1);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount / (endTime - startTime),
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
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

        assertEq(token.balanceOf(alice), amount - 1);
        assertEq(token.balanceOf(address(skillsHub)), 0);
    }

    function testSetEmploymentConfigSigFailed(uint256 amount) public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        uint256 deadline = startTime + 2 days;

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

    function testSetEmploymentConfigSigExpired(uint256 amount) public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        uint256 deadline = startTime - 1;

        // get random employment amount
        vm.assume(amount > 0 && amount <= 10);

        // transfer token
        token.transfer(address(alice), amount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount / (endTime - startTime),
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(
                SkillsHub__SignatureExpire.selector,
                uint256(deadline),
                uint256(block.timestamp)
            )
        );
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

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(skillsHub)), 0);
    }

    function testRenewalEmploymentConfig(uint256 renewalTime) public {
        // set config

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 3 days;
        renewalTime = endTime + 1 days;
        uint256 deadline = startTime + 2 days;

        uint256 amount = 456789;

        // transfer token
        token.transfer(address(alice), amount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount / (endTime - startTime),
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

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

        // renewal config

        uint256 additonalAmount = (amount * (renewalTime - endTime)) / (endTime - startTime);

        // transfer token
        token.transfer(address(alice), additonalAmount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount + additonalAmount);

        // construct signature(signer: developer(bob))
        employ = SigUtils.Employ({
            amount: (amount + additonalAmount) / (renewalTime - startTime),
            token: address(token),
            deadline: deadline
        });

        digest = sigUtils.getTypedDataHash(employ);
        (v, r, s) = vm.sign(bobPrivateKey, digest);
        signature = abi.encodePacked(r, s, v);

        expectEmit(CheckAll);
        emit Approval(address(alice), address(skillsHub), amount);
        expectEmit(CheckAll);
        emit Transfer(address(alice), address(skillsHub), additonalAmount);
        expectEmit(CheckAll);
        emit RenewalEmploymentConfig(
            1,
            address(alice),
            address(bob),
            address(token),
            amount + additonalAmount,
            additonalAmount,
            startTime,
            renewalTime
        );
        vm.prank(alice);
        skillsHub.renewalEmploymentConfig(1, renewalTime, deadline, signature);

        assertEq(token.balanceOf(address(skillsHub)), amount + additonalAmount);
        assertEq(token.balanceOf(alice), 0);
    }

    function testCancelEmployment() public {
        // set config
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        uint256 deadline = 123;

        uint256 amount = 456789;

        // transfer token
        token.transfer(address(alice), amount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount / (endTime - startTime),
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

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

        skip(7 hours);

        uint256 availableFund = _getAvailableSalary(amount, block.timestamp, startTime, endTime);

        // cancel config
        vm.expectEmit(true, true, false, false);
        emit CancelEmployment(1, address(token), amount - availableFund);
        vm.prank(alice);
        skillsHub.cancelEmployment(1);
    }

    function testClaimSalary() public {
        // set config
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;
        uint256 deadline = block.timestamp + 2 days;

        // get random employment amount
        uint256 amount = 456789;

        // transfer token
        token.transfer(address(alice), amount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount / (endTime - startTime),
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

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

        // skip some time
        skip(7 hours);

        // claim salary
        vm.expectEmit(true, true, false, false);
        emit ClaimSalary(
            1,
            address(token),
            _getAvailableSalary(amount, block.timestamp, startTime, endTime),
            block.timestamp
        );
        vm.prank(bob);
        skillsHub.claimSalary(1);

        // claim salalry again
        skip(3 hours);
        // claim salary
        vm.expectEmit(true, true, false, false);
        emit ClaimSalary(
            1,
            address(token),
            _getAvailableSalary(amount, block.timestamp, startTime, endTime),
            block.timestamp
        );
        vm.prank(bob);
        skillsHub.claimSalary(1);
    }

    function _getAvailableSalary(
        uint256 amount,
        uint256 currentTime,
        uint256 startTime,
        uint256 endTime
    ) internal pure returns (uint256) {
        if (currentTime >= endTime) {
            return amount;
        } else if (currentTime <= startTime) {
            return 0;
        } else {
            return (amount * (currentTime - startTime)) / (endTime - startTime);
        }
    }
}
