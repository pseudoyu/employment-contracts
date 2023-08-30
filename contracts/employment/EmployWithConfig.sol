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

    mapping(address feeReceiver => uint256 fraction) internal _feeFractions;
    mapping(address feeReceiver => mapping(string employmentConfigId => uint256 fraction))
        internal _feeFractions4Employment;
    // slither-disable-end naming-convention

    // events

    modifier onlyFeeReceiver(address feeReceiver) {
        require(feeReceiver == msg.sender, "TipsWithConfig: caller is not fee receiver");
        _;
    }

    modifier validateFraction(uint256 fraction) {
        require(fraction <= _feeDenominator(), "TipsWithConfig: fraction out of range");
        _;
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
