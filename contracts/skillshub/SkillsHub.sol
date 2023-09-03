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
 * @notice Logic to handle the employemnt that the employer can set the employment config for a cooperation.,
 * @dev Employer can set config for a specific employment, and developer can claim the salary by config id.
 *
 * For `SetEmploymentConfig`
 * Employer can set the employment config for a specific employment <br>
 *
 * For `claimSalary`
 * Anyone can claim the salary by employment id, and it will transfer all available tokens
 * from the contract account to the `developer` account.
 */
contract SkillsHub is Verifier, ISkillsHub, Initializable, ReentrancyGuard {
    using SafeERC20 for IERC20;

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

    // slither-disable-start naming-convention
    // address of web3Entry contract
    address internal _feeReceiver;

    uint256 internal _employmentConfigIndex;
    mapping(uint256 employmentConfigId => EmploymentConfig) internal _employmentConfigs;
    mapping(address feeReceiver => uint256 fraction) internal _feeFractions;
    // slither-disable-end naming-convention

    // events
    /**
     * @dev Emitted when a employer set the employment config.
     * @param employmentConfigId The employment signature.
     * @param employerAddress The employer address.```
     * @param developerAddress The developer address.
     * @param token The token address.
     * @param amount The amount of token.
     * @param startTime The start time of employment.
     * @param endTime The end time of employment.
     */
    event SetEmploymentConfig(
        uint256 indexed employmentConfigId,
        address indexed employerAddress,
        address indexed developerAddress,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime
    );

    /**
     * @dev Emitted when a employer renewal the employment config.
     * @param employmentConfigId The employment signature.
     * @param employerAddress The employer address.```
     * @param developerAddress The developer address.
     * @param token The token address.
     * @param amount The amount of token.
     * @param additonalAmount The additonal amount of token.
     * @param startTime The start time of employment.
     * @param endTime The end time of employment.
     */
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

    /**
     * @dev Emitted when a developer claim the salary.
     * @param employmentConfigId The employment signature.
     * @param token The token address.
     * @param claimAmount The amount of token.
     * @param lastClaimedTime The last claimed time.
     */
    event ClaimSalary(
        uint256 indexed employmentConfigId,
        address indexed token,
        uint256 indexed claimAmount,
        uint256 lastClaimedTime
    );

    /**
     * @dev Emitted when a developer claim the salary.
     * @param employmentConfigId The employment signature.
     * @param token The token address.
     * @param refundedAmount The amount of token.
     */
    event CancelEmployment(
        uint256 indexed employmentConfigId,
        address indexed token,
        uint256 indexed refundedAmount
    );

    modifier validateFraction(uint256 fraction) {
        if (fraction > _feeDenominator()) revert SkillsHub__FractionOutOfRange(fraction);

        _;
    }

    modifier validEmploymentId(uint256 employmentConfigId) {
        if (employmentConfigId <= 0)
            revert SkillsHub__EmploymentConfigIdInvalid(employmentConfigId);
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
        _feeFractions[feeReceiver] = fraction;
    }

    /// @inheritdoc ISkillsHub
    function setEmploymentConfig(
        address developer,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        uint256 deadline,
        bytes memory signature
    ) external override {
        if (endTime <= startTime) revert SkillsHub__EmploymentTimeInvalid(startTime, endTime);

        if (amount <= 0) revert SkillsHub__ConfigAmountInvalid(amount);

        uint256 employmentConfigId = ++_employmentConfigIndex;

        // add employments config
        _employmentConfigs[employmentConfigId] = EmploymentConfig({
            id: employmentConfigId,
            employer: msg.sender,
            developer: developer,
            token: token,
            amount: amount,
            claimedAmount: 0,
            startTime: startTime,
            endTime: endTime,
            lastClaimedTime: 0
        });

        address signer = _recoverEmploy(amount / (endTime - startTime), token, deadline, signature);

        if (signer != developer) revert SkillsHub__SignerInvalid(signer);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // set new employment config
        emit SetEmploymentConfig(
            employmentConfigId,
            msg.sender,
            developer,
            token,
            amount,
            startTime,
            endTime
        );
    }

    /// @inheritdoc ISkillsHub
    function renewalEmploymentConfig(
        uint256 employmentConfigId,
        uint256 endTime,
        uint256 deadline,
        bytes memory signature
    ) external override validEmploymentId(employmentConfigId) {
        EmploymentConfig storage config = _employmentConfigs[employmentConfigId];
        if (msg.sender != config.employer)
            revert SkillsHub__RenewalEmployerInconsistent(msg.sender);

        if (endTime <= config.endTime)
            revert SkillsHub__RenewalTimeInvalid(config.endTime, block.timestamp);

        if (block.timestamp >= config.endTime)
            revert SkillsHub__RenewalEmploymentAlreadyEnded(config.endTime, block.timestamp);

        // uint256 additonalAmount = (amount * (renewalTime - endTime)) / (endTime - startTime);
        uint256 additonalAmount = (config.amount * (endTime - config.endTime)) /
            (config.endTime - config.startTime);

        config.endTime = endTime;
        config.amount += additonalAmount;

        address signer = _recoverEmploy(
            config.amount / (config.endTime - config.startTime),
            config.token,
            deadline,
            signature
        );

        if (signer != config.developer) revert SkillsHub__SignerInvalid(signer);

        IERC20(config.token).safeTransferFrom(config.employer, address(this), additonalAmount);

        // set new employment config
        emit RenewalEmploymentConfig(
            employmentConfigId,
            msg.sender,
            config.developer,
            config.token,
            config.amount,
            additonalAmount,
            config.startTime,
            endTime
        );
    }

    /// @inheritdoc ISkillsHub
    function cancelEmployment(
        uint256 employmentConfigId
    ) external override validEmploymentId(employmentConfigId) {
        EmploymentConfig storage config = _employmentConfigs[employmentConfigId];
        if (msg.sender != config.employer) revert SkillsHub__CancelEmployerInconsistent(msg.sender);

        // calculate the available funds
        uint256 availableFund = _getAvailableSalary(
            config.amount,
            block.timestamp,
            config.startTime,
            config.endTime
        );

        if (config.amount > availableFund) {
            IERC20(config.token).safeTransfer(config.employer, config.amount - availableFund);
        }

        // emit event
        emit CancelEmployment(config.id, config.token, config.amount - availableFund);

        // delete employment config
        delete _employmentConfigs[config.id];
    }

    // @inheritdoc ISkillsHub
    function claimSalary(
        uint256 employmentConfigId
    ) external override validEmploymentId(employmentConfigId) nonReentrant {
        EmploymentConfig storage config = _employmentConfigs[employmentConfigId];
        if (msg.sender != config.developer)
            revert SkillsHub__ClaimSallaryDeveloperInconsistent(msg.sender);

        if (block.timestamp < config.startTime)
            revert SkillsHub__EmploymentNotStarted(config.startTime, block.timestamp);

        // calculate available funds
        uint256 claimAmount = _getAvailableSalary(
            config.amount,
            block.timestamp,
            config.startTime,
            config.endTime
        ) - config.claimedAmount;

        // claim avaliable funds
        if (claimAmount > 0) {
            uint256 fee = _getFeeAmount(_feeReceiver, claimAmount);
            IERC20(config.token).safeTransfer(config.developer, claimAmount - fee);

            if (fee > 0) {
                IERC20(config.token).safeTransfer(_feeReceiver, fee);
            }
        }

        config.claimedAmount += claimAmount;

        config.lastClaimedTime = block.timestamp;

        // emit event
        emit ClaimSalary(config.id, config.token, claimAmount, config.lastClaimedTime);
    }

    /// @inheritdoc ISkillsHub
    function getFeeFraction(address feeReceiver) external view override returns (uint256) {
        return _getFeeFraction(feeReceiver);
    }

    /// @inheritdoc ISkillsHub
    function getFeeAmount(
        address feeReceiver,
        uint256 amount
    ) external view override returns (uint256) {
        return _getFeeAmount(feeReceiver, amount);
    }

    /// @inheritdoc ISkillsHub
    function getEmploymentConfig(
        uint256 employmentConfigId
    )
        external
        view
        override
        validEmploymentId(employmentConfigId)
        returns (EmploymentConfig memory config)
    {
        return _employmentConfigs[employmentConfigId];
    }

    /// @inheritdoc ISkillsHub
    function getAvailableSalary(
        uint256 employmentConfigId,
        uint256 claimTimestamp
    ) external view override validEmploymentId(employmentConfigId) returns (uint256) {
        EmploymentConfig memory config = _employmentConfigs[employmentConfigId];
        return
            _getAvailableSalary(config.amount, claimTimestamp, config.startTime, config.endTime) -
            config.claimedAmount;
    }

    function _getFeeFraction(address feeReceiver) internal view returns (uint256) {
        // get default fraction
        return _feeFractions[feeReceiver];
    }

    function _getFeeAmount(address feeReceiver, uint256 amount) internal view returns (uint256) {
        uint256 fraction = _getFeeFraction(feeReceiver);
        return (amount * fraction) / _feeDenominator();
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

    /**
     * @dev Defaults to 10000 so fees are expressed in basis points.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }
}
