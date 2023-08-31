// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.18;

import {IEmployWithConfig} from "../interfaces/IEmployWithConfig.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title EmployWithConfig
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
contract EmployWithConfig is IEmployWithConfig, Initializable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(string employmentConfigId => EmploymentConfig) internal _employmentConfigs;
    mapping(address feeReceiver => uint256 fraction) internal _feeFractions;
    mapping(address feeReceiver => mapping(string employmentConfigId => uint256 fraction))
        internal _feeFractions4Employment;
    // slither-disable-end naming-convention

    // events
    /**
     * @dev Emitted when a employer set the employment config.
     * @param employmentConfigId The employment signature.
     * @param employerAddress The employer address.
     * @param developerAddress The developer address.
     * @param token The token address.
     * @param amount The amount of token.
     * @param startTime The start time of employment.
     * @param endTime The end time of employment.
     * @param feeReceiver The fee receiver address.
     */
    event SetEmploymentConfig(
        string indexed employmentConfigId,
        address indexed employerAddress,
        address indexed developerAddress,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        address feeReceiver
    );

    /**
     * @dev Emitted when a developer claim the salary.
     * @param employmentConfigId The employment signature.
     * @param token The token address.
     * @param amount The amount of token.
     */
    event ClaimEmployment(string indexed employmentConfigId, address token, uint256 amount);

    /**
     * @dev Emitted when a developer claim the salary.
     * @param employmentConfigId The employment signature.
     * @param token The token address.
     * @param amount The amount of token.
     */
    event CancelEmployment(string indexed employmentConfigId, address token, uint256 amount);

    modifier onlyFeeReceiver(address feeReceiver) {
        require(feeReceiver == msg.sender, "EmployWithConfig: caller is not fee receiver");
        _;
    }

    modifier validateFraction(uint256 fraction) {
        require(fraction <= _feeDenominator(), "EmployWithConfig: fraction out of range");
        _;
    }

    /// @inheritdoc IEmployWithConfig
    function initialize() external override {
        // solhint-disable-next-line avoid-tx-origin
        require(tx.origin == msg.sender, "EmployWithConfig: FORBIDDEN");
    }

    /// @inheritdoc IEmployWithConfig
    function setDefaultFeeFraction(
        address feeReceiver,
        uint256 fraction
    ) external override onlyFeeReceiver(feeReceiver) validateFraction(fraction) {
        _feeFractions[feeReceiver] = fraction;
    }

    /// @inheritdoc IEmployWithConfig
    function setFeeFraction(
        string calldata employmentConfigId,
        address feeReceiver,
        uint256 fraction
    ) external override onlyFeeReceiver(feeReceiver) validateFraction(fraction) {
        _feeFractions4Employment[feeReceiver][employmentConfigId] = fraction;
    }

    /// @inheritdoc IEmployWithConfig
    function setEmploymentConfig(
        string calldata employmentConfigId,
        address developer,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        address feeReceiver
    ) external override {
        // solhint-disable-next-line not-rely-on-time
        require(startTime >= block.timestamp, "EmployWithConfig: start time must be future");
        require(endTime > startTime, "EmployWithConfig: end time must be greater than start time");
        require(amount > 0, "EmployWithConfig: amount must be greater than zero");

        // set the employment config
        emit SetEmploymentConfig(
            employmentConfigId,
            msg.sender,
            developer,
            token,
            amount,
            startTime,
            endTime,
            feeReceiver
        );
    }

    /// @inheritdoc IEmployWithConfig
    function cancelEmployment(string calldata employmentConfigId) external override {
        EmploymentConfig storage config = _employmentConfigs[employmentConfigId];
        require(msg.sender == config.employer, "EmployWithConfig: not employer");

        // collect remaining funds first

        // delete tips config
        delete _employmentConfigs[config.id];

        // emit event
        emit CancelEmployment(config.id, config.token, config.amount);
    }

    // @inheritdoc IEmployWithConfig
    function claimSalary(string calldata employmentConfigId) external override nonReentrant {
        EmploymentConfig storage config = _employmentConfigs[employmentConfigId];
        require(msg.sender == config.developer, "EmployWithConfig: not developer");

        // collect remaining funds first
        uint256 amount = IERC20(config.token).balanceOf(address(this));
        if (amount > 0) {
            IERC20(config.token).safeTransfer(config.developer, amount);
        }

        // emit event
        emit ClaimEmployment(config.id, config.token, amount);
    }

    /// @inheritdoc IEmployWithConfig
    function getFeeFraction(
        string calldata employmentConfigId,
        address feeReceiver
    ) external view override returns (uint256) {
        return _getFeeFraction(employmentConfigId, feeReceiver);
    }

    /// @inheritdoc IEmployWithConfig
    function getFeeAmount(
        string calldata employmentConfigId,
        address feeReceiver,
        uint256 tipAmount
    ) external view override returns (uint256) {
        return _getFeeAmount(employmentConfigId, feeReceiver, tipAmount);
    }

    /// @inheritdoc IEmployWithConfig
    function getEmploymentConfig(
        string calldata employmentConfigId
    ) external view override returns (EmploymentConfig memory config) {
        return _employmentConfigs[employmentConfigId];
    }

    function _getFeeFraction(
        string calldata employmentConfigId,
        address feeReceiver
    ) internal view returns (uint256) {
        // get character fraction
        uint256 fraction = _feeFractions4Employment[feeReceiver][employmentConfigId];
        if (fraction > 0) return fraction;
        // get default fraction
        return _feeFractions[feeReceiver];
    }

    function _getFeeAmount(
        string calldata employmentConfigId,
        address feeReceiver,
        uint256 tipAmount
    ) internal view returns (uint256) {
        uint256 fraction = _getFeeFraction(employmentConfigId, feeReceiver);
        return (tipAmount * fraction) / _feeDenominator();
    }

    /**
     * @dev Defaults to 10000 so fees are expressed in basis points.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }
}
