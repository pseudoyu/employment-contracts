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
    bytes32 public DOMAIN_SEPARATOR;

    SigUtils internal sigUtils;

    // events
    event StartEmployment(
        uint256 employmentId,
        address employerAddress,
        address developerAddress,
        address token,
        uint256 amount,
        uint256 time,
        uint256 startTime,
        uint256 endTime
    );

    event ExtendEmployment(
        uint256 employmentId,
        uint256 amount,
        uint256 time,
        uint256 additonalAmount,
        uint256 endTime
    );

    event ClaimFund(
        uint256 employmentId,
        uint256 claimAmount,
        uint256 claimedAmount,
        uint256 lastClaimedTime,
        uint256 feeAmount
    );

    event CancelEmployment(uint256 employmentId, uint256 refundedAmount, uint256 cancelTime);

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
    error SkillsHub__EmploymentIdInvalid(uint256 employmentId);
    error SkillsHub__EmploymentTimeInvalid(uint256 time);
    error SkillsHub__ExtendTimeInvalid(uint256 endTime, uint256 renewalTime);
    error SkillsHub__AmountInvalid(uint256 amount);
    error SkillsHub__FractionOutOfRange(uint256 fraction);
    error SkillsHub__ExtendEmployerInconsistent(address employer);
    error SkillsHub__ExtendEmploymentAlreadyEnded(uint256 endTime, uint256 renewalTime);
    error SkillsHub__CancelEmployerInconsistent(address employer);
    error SkillsHub__ClaimFundDeveloperInconsistent(address developer);
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

        assertEq(skillsHub.getFeeFraction(), fraction);
    }

    function testSetFractionFailed(uint256 fraction) public {
        vm.assume(fraction > 10000);

        vm.expectRevert(
            abi.encodeWithSelector(SkillsHub__FractionOutOfRange.selector, uint256(fraction))
        );
        vm.startPrank(alice);
        skillsHub.setFeeFraction(alice, fraction);

        assertEq(skillsHub.getFeeFraction(), 0);
    }

    function testStartEmployment(uint256 amount) public {
        uint256 time = 5 days;

        vm.assume(amount > 100000000 && amount <= 1000000000);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + time;
        uint256 deadline = startTime + 7 days;

        // transfer token
        token.transfer(address(alice), amount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount,
            time: time,
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        expectEmit(CheckAll);
        emit Approval(alice, address(skillsHub), 0);

        expectEmit(CheckAll);
        emit Transfer(alice, address(skillsHub), amount);

        expectEmit(CheckAll);
        emit StartEmployment(1, alice, bob, address(token), amount, time, startTime, endTime);

        vm.prank(alice);
        skillsHub.startEmployment(bob, address(token), amount, time, deadline, signature);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(skillsHub)), amount);
    }

    function testStartEmploymentInsufficientAllowance(uint256 amount) public {
        uint256 time = 5 days;

        vm.assume(amount > 100000000 && amount <= 1000000000);

        uint256 startTime = block.timestamp;
        uint256 deadline = startTime + 7 days;

        // transfer token
        token.transfer(address(alice), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount,
            time: time,
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(alice);
        skillsHub.startEmployment(bob, address(token), amount, time, deadline, signature);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(skillsHub)), 0);
    }

    function testStartEmploymentInsufficientBalance(uint256 amount) public {
        uint256 time = 5 days;

        vm.assume(amount > 100000000 && amount <= 1000000000);

        uint256 startTime = block.timestamp;
        uint256 deadline = startTime + 7 days;

        // transfer token
        token.transfer(address(alice), amount - 1);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount,
            time: time,
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(alice);
        skillsHub.startEmployment(bob, address(token), amount, time, deadline, signature);

        assertEq(token.balanceOf(alice), amount - 1);
        assertEq(token.balanceOf(address(skillsHub)), 0);
    }

    function testStartEmploymentSigFailed(uint256 amount) public {
        uint256 time = 5 days;

        vm.assume(amount > 100000000 && amount <= 1000000000);

        uint256 startTime = block.timestamp;
        uint256 deadline = startTime + 7 days;

        // transfer token
        token.transfer(address(alice), amount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount,
            time: time,
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(SkillsHub__SignerInvalid.selector, address(alice)));
        vm.prank(alice);
        skillsHub.startEmployment(bob, address(token), amount, time, deadline, signature);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(skillsHub)), 0);
    }

    function testStartEmploymentSigExpired(uint256 amount) public {
        uint256 time = 5 days;

        vm.assume(amount > 100000000 && amount <= 1000000000);

        uint256 deadline = block.timestamp - 1;

        // transfer token
        token.transfer(address(alice), amount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount,
            time: time,
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
        skillsHub.startEmployment(bob, address(token), amount, time, deadline, signature);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(skillsHub)), 0);
    }

    function testExtendEmployment(uint256 amount) public {
        uint256 time = 5 days;

        vm.assume(amount > 100000000 && amount <= 1000000000);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + time;
        uint256 extendTime = 3 days;
        uint256 deadline = startTime + 7 days;

        // transfer token
        token.transfer(address(alice), amount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount,
            time: time,
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(alice);
        skillsHub.startEmployment(bob, address(token), amount, time, deadline, signature);

        // extend employment
        uint256 additonalAmount = extendTime * (amount / time);

        // transfer token
        token.transfer(address(alice), additonalAmount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount + additonalAmount);

        // construct signature(signer: developer(bob))
        employ = SigUtils.Employ({
            amount: amount + additonalAmount,
            time: time + extendTime,
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
        emit ExtendEmployment(
            1,
            amount + additonalAmount,
            time + extendTime,
            additonalAmount,
            endTime + extendTime
        );
        vm.prank(alice);
        skillsHub.extendEmployment(1, extendTime);

        assertEq(token.balanceOf(address(skillsHub)), amount + additonalAmount);
        assertEq(token.balanceOf(alice), 0);
    }

    function testCancelEmployment(uint256 amount) public {
        uint256 time = 5 days;

        vm.assume(amount > 100000000 && amount <= 1000000000);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + time;
        uint256 deadline = startTime + 7 days;

        // transfer token
        token.transfer(address(alice), amount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount,
            time: time,
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(alice);
        skillsHub.startEmployment(bob, address(token), amount, time, deadline, signature);

        uint256 availableFund = _getAvailableFund(amount, block.timestamp, startTime, endTime);

        // cancel employment
        vm.expectEmit(true, true, false, false);
        emit CancelEmployment(1, amount - availableFund, block.timestamp);

        vm.prank(alice);
        skillsHub.cancelEmployment(1);
    }

    function testClaimFund(uint256 amount) public {
        uint256 time = 5 days;

        vm.assume(amount > 100000000 && amount <= 1000000000);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + time;
        uint256 deadline = startTime + 7 days;

        // transfer token
        token.transfer(address(alice), amount);

        // approve token
        vm.prank(alice);
        token.approve(address(skillsHub), amount);

        // construct signature(signer: developer(bob))
        SigUtils.Employ memory employ = SigUtils.Employ({
            amount: amount,
            time: time,
            token: address(token),
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(employ);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(alice);
        skillsHub.startEmployment(bob, address(token), amount, time, deadline, signature);

        // claim salary
        vm.expectEmit(true, true, false, false);
        emit ClaimFund(
            1,
            _getAvailableFund(amount, block.timestamp, startTime, endTime),
            _getAvailableFund(amount, block.timestamp, startTime, endTime),
            block.timestamp,
            0
        );
        vm.prank(bob);
        skillsHub.claimFund(1);

        // claim salalry again
        // claim salary
        vm.expectEmit(true, true, false, false);
        emit ClaimFund(
            1,
            _getAvailableFund(amount, block.timestamp, startTime, endTime),
            _getAvailableFund(amount, block.timestamp, startTime, endTime),
            block.timestamp,
            0
        );
        vm.prank(bob);
        skillsHub.claimFund(1);
    }

    function _getAvailableFund(
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
