// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.18;

import {ISkillsHub} from "../interfaces/ISkillsHub.sol";
import {VerifySignature} from "../libraries/VerifySignature.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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
contract SkillsHub is ISkillsHub, Initializable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // slither-disable-start naming-convention
    // address of web3Entry contract
    address internal _feeReceiver;

    uint256 internal _employmentConfigIndex;
    mapping(uint256 employmentConfigId => EmploymentConfig) internal _employmentConfigs;
    mapping(address feeReceiver => uint256 fraction) internal _feeFractions;
    mapping(address feeReceiver => mapping(uint256 employmentConfigId => uint256 fraction))
        internal _feeFractions4Employment;
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
        address token,
        uint256 claimAmount,
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
        address token,
        uint256 refundedAmount
    );

    modifier onlyFeeReceiver(address feeReceiver) {
        require(feeReceiver == msg.sender, "EmployWithConfig: caller is not fee receiver");
        _;
    }

    modifier validateFraction(uint256 fraction) {
        require(fraction <= _feeDenominator(), "EmployWithConfig: fraction out of range");
        _;
    }

    modifier validEmploymentId(uint256 employmentConfigId) {
        require(employmentConfigId > 0, "EmployWithConfig: employmentConfigId is empty");
        _;
    }

    modifier vaildSignature(
        address developer,
        address employer,
        uint256 startTime,
        uint256 endTime,
        bytes memory signature
    ) {
        require(
            _verifySignature(developer, employer, startTime, endTime, signature),
            "EmployWithConfig: invalid signature"
        );
        _;
    }

    /// @inheritdoc ISkillsHub
    function initialize(address feeReceiver_) external override initializer {
        _feeReceiver = feeReceiver_;
    }

    /// @inheritdoc ISkillsHub
    function setDefaultFeeFraction(
        address feeReceiver,
        uint256 fraction
    ) external override onlyFeeReceiver(feeReceiver) validateFraction(fraction) {
        _feeFractions[feeReceiver] = fraction;
    }

    /// @inheritdoc ISkillsHub
    function setFeeFraction(
        uint256 employmentConfigId,
        address feeReceiver,
        uint256 fraction
    ) external override onlyFeeReceiver(feeReceiver) validateFraction(fraction) {
        _feeFractions4Employment[feeReceiver][employmentConfigId] = fraction;
    }

    /// @inheritdoc ISkillsHub
    function setEmploymentConfig(
        address developer,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        bytes memory signature
    ) external override vaildSignature(developer, msg.sender, startTime, endTime, signature) {
        require(endTime > startTime, "EmployWithConfig: end time must be greater than start time");
        require(amount > 0, "EmployWithConfig: amount must be greater than zero");

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
        bytes memory signature
    ) external override validEmploymentId(employmentConfigId) {
        EmploymentConfig storage config = _employmentConfigs[employmentConfigId];
        require(
            _verifySignature(config.developer, msg.sender, config.startTime, endTime, signature),
            "EmployWithConfig: invalid signature"
        );
        require(msg.sender == config.employer, "EmployWithConfig: not employer");
        require(block.timestamp < config.endTime, "EmployWithConfig: project already ended");
        require(
            endTime > config.startTime,
            "EmployWithConfig: end time must be greater than start time"
        );
        require(endTime > config.endTime, "EmployWithConfig: end time must be greater than before");

        config.endTime = endTime;

        uint256 additonalAmount = (config.amount * (endTime - config.endTime)) /
            (config.endTime - config.startTime);

        config.amount += additonalAmount;

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
        require(msg.sender == config.employer, "EmployWithConfig: not employer");

        // calculate the remaining funds
        if (config.amount > config.claimedAmount) {
            IERC20(config.token).safeTransfer(
                config.employer,
                config.amount - config.claimedAmount
            );
        }

        // delete employment config
        delete _employmentConfigs[config.id];

        // emit event
        emit CancelEmployment(config.id, config.token, config.amount - config.claimedAmount);
    }

    // @inheritdoc ISkillsHub
    function claimSalary(
        uint256 employmentConfigId
    ) external override validEmploymentId(employmentConfigId) nonReentrant {
        EmploymentConfig storage config = _employmentConfigs[employmentConfigId];
        require(msg.sender == config.developer, "EmployWithConfig: not developer");
        require(block.timestamp >= config.startTime, "EmployWithConfig: project not started");

        // calculate available funds
        uint256 claimAmount = _getAvailableSalary(
            config.amount,
            block.timestamp,
            config.startTime,
            config.endTime
        ) - config.claimedAmount;

        // claim avaliable funds
        if (claimAmount > 0) {
            uint256 fee = _getFeeAmount(employmentConfigId, _feeReceiver, claimAmount);
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

    function _verifySignature(
        address developer,
        address employer,
        uint256 startTime,
        uint256 endTime,
        bytes memory signature
    ) internal pure returns (bool) {
        return VerifySignature.verify(developer, employer, startTime, endTime, signature);
    }

    /// @inheritdoc ISkillsHub
    function getFeeFraction(
        uint256 employmentConfigId,
        address feeReceiver
    ) external view override validEmploymentId(employmentConfigId) returns (uint256) {
        return _getFeeFraction(employmentConfigId, feeReceiver);
    }

    /// @inheritdoc ISkillsHub
    function getFeeAmount(
        uint256 employmentConfigId,
        address feeReceiver,
        uint256 amount
    ) external view override validEmploymentId(employmentConfigId) returns (uint256) {
        return _getFeeAmount(employmentConfigId, feeReceiver, amount);
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

    /// @inheritdoc ISkillsHub
    function verifySignature(
        address developer,
        address employer,
        uint256 startTime,
        uint256 endTime,
        bytes memory signature
    ) external pure override returns (bool) {
        return _verifySignature(developer, employer, startTime, endTime, signature);
    }

    function _getFeeFraction(
        uint256 employmentConfigId,
        address feeReceiver
    ) internal view returns (uint256) {
        // get character fraction
        uint256 fraction = _feeFractions4Employment[feeReceiver][employmentConfigId];
        if (fraction > 0) return fraction;
        // get default fraction
        return _feeFractions[feeReceiver];
    }

    function _getFeeAmount(
        uint256 employmentConfigId,
        address feeReceiver,
        uint256 amount
    ) internal view returns (uint256) {
        uint256 fraction = _getFeeFraction(employmentConfigId, feeReceiver);
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
