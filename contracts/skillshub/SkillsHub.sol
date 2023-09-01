// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.18;

import {ISkillsHub} from "../interfaces/ISkillsHub.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
contract SkillsHub is ISkillsHub, ReentrancyGuard {
    using SafeERC20 for IERC20;

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
     * @param feeReceiver The fee receiver address.
     */
    event SetEmploymentConfig(
        uint256 indexed employmentConfigId,
        address indexed employerAddress,
        address indexed developerAddress,
        address token,
        uint256 amount,
        uint256 refundedAmount,
        uint256 additonalAmount,
        uint256 startTime,
        uint256 endTime,
        address feeReceiver
    );

    /**
     * @dev Emitted when a developer claim the salary.
     * @param employmentConfigId The employment signature.
     * @param token The token address.
     * @param claimAmount The amount of token.
     */
    event ClaimSalary(uint256 indexed employmentConfigId, address token, uint256 claimAmount);

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

    modifier configIdNotEmpty(uint256 employmentConfigId) {
        require(employmentConfigId > 0, "EmployWithConfig: employmentConfigId is empty");
        _;
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
        uint256 employmentConfigId,
        uint256 prevEmploymentConfigId,
        address developer,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        address feeReceiver
    ) external override configIdNotEmpty(employmentConfigId) {
        require(endTime > startTime, "EmployWithConfig: end time must be greater than start time");
        require(amount > 0, "EmployWithConfig: amount must be greater than zero");

        uint256 refundedAmount;
        uint256 additonalAmount;

        if (prevEmploymentConfigId > 0) {
            EmploymentConfig storage prevConfig = _employmentConfigs[prevEmploymentConfigId];

            // add new employments config
            _employmentConfigs[employmentConfigId] = EmploymentConfig({
                id: employmentConfigId,
                employer: msg.sender,
                developer: developer,
                token: token,
                amount: amount,
                claimedAmount: prevConfig.claimedAmount,
                // start time and end time can not be changed
                startTime: prevConfig.startTime,
                endTime: prevConfig.endTime,
                feeReceiver: feeReceiver
            });

            if (amount > prevConfig.amount) {
                additonalAmount = amount - prevConfig.amount;
                IERC20(prevConfig.token).safeTransferFrom(
                    prevConfig.employer,
                    address(this),
                    additonalAmount
                );
            } else if (amount < prevConfig.amount) {
                require(
                    amount > prevConfig.claimedAmount,
                    "EmployWithConfig: can not be smaller than claimed amount"
                );
                refundedAmount = prevConfig.amount - amount;
                IERC20(prevConfig.token).safeTransfer(prevConfig.employer, refundedAmount);
            }

            // delete previous config
            delete _employmentConfigs[prevEmploymentConfigId];
        } else {
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
                feeReceiver: feeReceiver
            });

            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        // set new employment config
        emit SetEmploymentConfig(
            employmentConfigId,
            msg.sender,
            developer,
            token,
            amount,
            refundedAmount,
            additonalAmount,
            startTime,
            endTime,
            feeReceiver
        );
    }

    /// @inheritdoc ISkillsHub
    function cancelEmployment(
        uint256 employmentConfigId
    ) external override configIdNotEmpty(employmentConfigId) {
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
        uint256 employmentConfigId,
        uint256 claimTimestamp
    ) external override configIdNotEmpty(employmentConfigId) nonReentrant {
        EmploymentConfig storage config = _employmentConfigs[employmentConfigId];
        require(msg.sender == config.developer, "EmployWithConfig: not developer");
        require(claimTimestamp >= config.startTime, "EmployWithConfig: project not started");

        // calculate available funds
        uint256 claimAmount = _getAvailableSalary(
            config.amount,
            claimTimestamp,
            config.startTime,
            config.endTime
        ) - config.claimedAmount;

        // claim avaliable funds
        if (claimAmount > 0) {
            uint256 fee = _getFeeAmount(employmentConfigId, config.feeReceiver, claimAmount);
            IERC20(config.token).safeTransfer(config.developer, claimAmount - fee);

            if (fee > 0) {
                IERC20(config.token).safeTransfer(config.feeReceiver, fee);
            }
        }

        // emit event
        emit ClaimSalary(config.id, config.token, claimAmount);
    }

    /// @inheritdoc ISkillsHub
    function getFeeFraction(
        uint256 employmentConfigId,
        address feeReceiver
    ) external view override configIdNotEmpty(employmentConfigId) returns (uint256) {
        return _getFeeFraction(employmentConfigId, feeReceiver);
    }

    /// @inheritdoc ISkillsHub
    function getFeeAmount(
        uint256 employmentConfigId,
        address feeReceiver,
        uint256 amount
    ) external view override configIdNotEmpty(employmentConfigId) returns (uint256) {
        return _getFeeAmount(employmentConfigId, feeReceiver, amount);
    }

    /// @inheritdoc ISkillsHub
    function getEmploymentConfig(
        uint256 employmentConfigId
    )
        external
        view
        override
        configIdNotEmpty(employmentConfigId)
        returns (EmploymentConfig memory config)
    {
        return _employmentConfigs[employmentConfigId];
    }

    /// @inheritdoc ISkillsHub
    function getAvailableSalary(
        uint256 employmentConfigId,
        uint256 claimTimestamp
    ) external view override configIdNotEmpty(employmentConfigId) returns (uint256) {
        EmploymentConfig memory config = _employmentConfigs[employmentConfigId];
        return
            _getAvailableSalary(config.amount, claimTimestamp, config.startTime, config.endTime) -
            config.claimedAmount;
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
