// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.18;

import {ISkillsHub} from "../interfaces/ISkillsHub.sol";
import {Verifier} from "../signature/Verifier.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

/**
 * @title SkillsHub
 * @notice Logic to handle the employemnt that the employer can start the employment,
 * @dev Employer can start employment, and developer can claim the fund by employment id.
 *
 * For `StartEmployment`
 * Employer can start the employment<br>
 *
 * For `claimFund`
 * Anyone can claim the fund by employment id, and it will transfer all available tokens
 * from the contract account to the `developer` account.
 */
contract SkillsHub is Verifier, ISkillsHub, Initializable, ReentrancyGuard {
    using SafeERC20 for IERC20;

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

    // slither-disable-start naming-convention
    // address of web3Entry contract
    address internal _feeReceiver;
    uint256 internal _fraction;

    uint256 internal _employmentIndex;
    mapping(uint256 employmentId => Employment) internal _employments;
    // slither-disable-end naming-convention

    // events
    /**
     * @dev Emitted when a employer start the employment.
     * @param employmentId The employment signature.
     * @param employerAddress The employer address.
     * @param developerAddress The developer address.
     * @param token The token address.
     * @param amount The amount of token.
     * @param time The total time of employment.
     * @param startTime The start time of employment.
     * @param endTime The end time of employment.
     */
    event StartEmployment(
        uint256 indexed employmentId,
        address indexed employerAddress,
        address indexed developerAddress,
        address token,
        uint256 amount,
        uint256 time,
        uint256 startTime,
        uint256 endTime
    );

    /**
     * @dev Emitted when a employer extend the employment.
     * @param employmentId The employment signature.
     * @param amount The amount of token.
     * @param time The total time of employment.
     * @param additonalAmount The additonal amount that should deposit.
     * @param endTime The end time of employment.
     */
    event ExtendEmployment(
        uint256 indexed employmentId,
        uint256 indexed amount,
        uint256 indexed time,
        uint256 additonalAmount,
        uint256 endTime
    );

    /**
     * @dev Emitted when a developer claim the fund.
     * @param employmentId The employment signature.
     * @param claimAmount The amount of token.
     * @param lastClaimedTime The last claimed time.
     */
    event ClaimFund(
        uint256 indexed employmentId,
        uint256 indexed claimAmount,
        uint256 indexed claimedAmount,
        uint256 lastClaimedTime,
        uint256 feeAmount
    );

    /**
     * @dev Emitted when a employer cancel the employment.
     * @param employmentId The employment signature.
     * @param refundedAmount The amount of token.
     * @param cancelTime The cancel time.
     */
    event CancelEmployment(
        uint256 indexed employmentId,
        uint256 indexed refundedAmount,
        uint256 indexed cancelTime
    );

    modifier validateFraction(uint256 fraction) {
        if (fraction > _feeDenominator()) revert SkillsHub__FractionOutOfRange(fraction);

        _;
    }

    modifier validEmploymentId(uint256 employmentId) {
        if (employmentId <= 0) revert SkillsHub__EmploymentIdInvalid(employmentId);
        _;
    }

    /// @inheritdoc ISkillsHub
    function initialize(address feeReceiver_) external override initializer {
        _feeReceiver = feeReceiver_;
    }

    /// @inheritdoc ISkillsHub
    function setFeeFraction(
        address feeReceiver,
        uint256 fraction
    ) external override validateFraction(fraction) {
        _feeReceiver = feeReceiver;
        _fraction = fraction;
    }

    /// @inheritdoc ISkillsHub
    function startEmployment(
        address developer,
        address token,
        uint256 amount,
        uint256 time,
        uint256 deadline,
        bytes memory signature
    ) external override {
        if (time <= 0) revert SkillsHub__EmploymentTimeInvalid(time);

        if (amount <= 0) revert SkillsHub__AmountInvalid(amount);

        if (block.timestamp > deadline)
            revert SkillsHub__SignatureExpire(deadline, block.timestamp);

        uint256 employmentId = ++_employmentIndex;

        // add employments
        _employments[employmentId] = Employment({
            employer: msg.sender,
            developer: developer,
            token: token,
            amount: amount,
            claimedAmount: 0,
            time: time,
            startTime: block.timestamp,
            endTime: block.timestamp + time
        });

        address signer = _recoverEmploy(amount, time, token, deadline, signature);

        if (signer != developer) revert SkillsHub__SignerInvalid(signer);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit StartEmployment(
            employmentId,
            msg.sender,
            developer,
            token,
            amount,
            time,
            block.timestamp,
            block.timestamp + time
        );
    }

    /// @inheritdoc ISkillsHub
    function extendEmployment(
        uint256 employmentId,
        uint256 extendTime,
        uint256 deadline,
        bytes memory signature
    ) external override validEmploymentId(employmentId) {
        Employment storage employment = _employments[employmentId];
        if (msg.sender != employment.employer)
            revert SkillsHub__ExtendEmployerInconsistent(msg.sender);

        if (block.timestamp >= employment.endTime)
            revert SkillsHub__ExtendEmploymentAlreadyEnded(employment.endTime, block.timestamp);

        if (block.timestamp > deadline)
            revert SkillsHub__SignatureExpire(deadline, block.timestamp);

        uint256 additonalAmount = (employment.amount / employment.time) * extendTime;

        employment.amount += additonalAmount;
        employment.time += extendTime;
        employment.endTime += extendTime;

        address signer = _recoverEmploy(
            employment.amount,
            employment.time,
            employment.token,
            deadline,
            signature
        );

        if (signer != employment.developer) revert SkillsHub__SignerInvalid(signer);

        IERC20(employment.token).safeTransferFrom(
            employment.employer,
            address(this),
            additonalAmount
        );

        emit ExtendEmployment(
            employmentId,
            employment.amount,
            employment.time,
            additonalAmount,
            employment.endTime
        );
    }

    /// @inheritdoc ISkillsHub
    function cancelEmployment(
        uint256 employmentId
    ) external override validEmploymentId(employmentId) {
        Employment storage employment = _employments[employmentId];
        if (msg.sender != employment.employer)
            revert SkillsHub__CancelEmployerInconsistent(msg.sender);

        // calculate the available funds
        uint256 availableFund = _getAvailableFund(
            employment.amount,
            block.timestamp,
            employment.startTime,
            employment.endTime
        );

        if (employment.amount > availableFund) {
            IERC20(employment.token).safeTransfer(
                employment.employer,
                employment.amount - availableFund
            );
        }

        // emit event
        emit CancelEmployment(employmentId, employment.amount - availableFund, block.timestamp);

        // delete employment config
        delete _employments[employmentId];
    }

    // @inheritdoc ISkillsHub
    function claimFund(
        uint256 employmentId
    ) external override validEmploymentId(employmentId) nonReentrant {
        Employment storage employment = _employments[employmentId];
        if (msg.sender != employment.developer)
            revert SkillsHub__ClaimFundDeveloperInconsistent(msg.sender);

        if (block.timestamp < employment.startTime)
            revert SkillsHub__EmploymentNotStarted(employment.startTime, block.timestamp);

        // calculate available funds
        uint256 claimAmount = _getAvailableFund(
            employment.amount,
            block.timestamp,
            employment.startTime,
            employment.endTime
        ) - employment.claimedAmount;

        // claim avaliable funds
        uint256 fee = _getFeeAmount(claimAmount);

        if (claimAmount > 0) {
            IERC20(employment.token).safeTransfer(employment.developer, claimAmount - fee);

            if (fee > 0) {
                IERC20(employment.token).safeTransfer(_feeReceiver, fee);
            }
        }

        employment.claimedAmount += claimAmount;

        // emit event
        emit ClaimFund(employmentId, claimAmount, employment.claimedAmount, block.timestamp, fee);
    }

    /// @inheritdoc ISkillsHub
    function getFeeFraction() external view override returns (uint256) {
        return _fraction;
    }

    /// @inheritdoc ISkillsHub
    function getFeeAmount(uint256 amount) external view override returns (uint256) {
        return _getFeeAmount(amount);
    }

    /// @inheritdoc ISkillsHub
    function getEmploymentInfo(
        uint256 employmentId
    )
        external
        view
        override
        validEmploymentId(employmentId)
        returns (Employment memory employment)
    {
        return _employments[employmentId];
    }

    function getCurrentEmploymentIndex() external view override returns (uint256) {
        return _employmentIndex;
    }

    /// @inheritdoc ISkillsHub
    function getAvailableFund(
        uint256 employmentId
    ) external view override validEmploymentId(employmentId) returns (uint256) {
        Employment memory employment = _employments[employmentId];
        uint256 availableFund = _getAvailableFund(
            employment.amount,
            block.timestamp,
            employment.startTime,
            employment.endTime
        ) - employment.claimedAmount;

        return availableFund - _getFeeAmount(availableFund);
    }

    /// @inheritdoc ISkillsHub
    function getClaimedFund(uint256 employmentId) external view returns (uint256) {
        Employment memory employment = _employments[employmentId];
        return employment.claimedAmount;
    }

    function _getFeeAmount(uint256 amount) internal view returns (uint256) {
        return (amount * _fraction) / _feeDenominator();
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

    /**
     * @dev Defaults to 10000 so fees are expressed in basis points.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }
}
