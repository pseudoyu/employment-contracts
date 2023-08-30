// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

/**
 * @title IEmployWithConfig
 * @notice This is the interface for the EmployWithConfig contract.
 */

interface IEmployWithConfig {
    struct EmploymentConfig {
        string id;
        address developer;
        address token;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        address feeReceiver;
    }

    /**
     * @notice Initialize the contract, setting web3Entry address.
     */
    function initialize() external;

    /**
     * @notice Sets the default fee percentage of specific receiver.
     * @dev The feeReceiver can be a platform account.
     * @param feeReceiver The fee receiver address.
     * @param fraction The percentage measured in basis points. Each basis point represents 0.01%.
     */
    function setDefaultFeeFraction(address feeReceiver, uint256 fraction) external;

    /**
     * @notice Sets the fee percentage of specific <receiver, employmentId>.
     * @dev If this is set, it will override the default fee fraction.
     * @param employmentConfigId The employment ID.
     * @param feeReceiver The fee receiver address.
     * @param fraction The percentage measured in basis points. Each basis point represents 0.01%.
     */
    function setFeeFraction(
        string calldata employmentConfigId,
        address feeReceiver,
        uint256 fraction
    ) external;

    /**
     * @notice Sets the employment config of specific employment id. <br>
     * Emits a {SetEmploymentConfig} event.
     * @dev If the employment config of specific <fromCharacter, toCharacter> is already,
     * it will try to collect the employment first, and then override the employment config.
     * @param employmentConfigId The employment signature.
     * @param develper The developer address.
     * @param token The token address.
     * @param amount The amount of token.
     * @param startTime The start time of employment.
     * @param endTime The end time of employment.
     * @param feeReceiver The fee receiver address.
     */
    function setEmploymentConfig(
        string calldata employmentConfigId,
        uint256 develper,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 endTime,
        address feeReceiver
    ) external;

    /**
     * @notice Cancels the employment. <br>
     * Emits a {CancelEmployment} event.
     * @dev It will try to collect the remaining assets first, and then delete the employment config.
     * @dev Only the employment creator can cancel the employment.
     * @param employmentConfigId The employment config ID to cancel.
     */
    function cancelEmployment(uint256 employmentConfigId) external;

    /**
     * @notice Claims all unredeemed salary from the contract to developer address. <br>
     * Emits a {ClaimEmployment} event if claims successfully.
     * @dev It will transfer all unredeemed token from the contract to the `developer`.
     * @param employmentConfigId The employment config ID.
     */
    function claimSalary(uint256 employmentConfigId) external;

    /**
     * @notice Returns the fee percentage of specific <receiver, employment>.
     * @dev It will return the first non-zero value by priority feeFraction4Character and defaultFeeFraction.
     * @param employmentConfigId The employment config ID.
     * @param feeReceiver The fee receiver address.
     * @return fraction The percentage measured in basis points. Each basis point represents 0.01%.
     */
    function getFeeFraction(
        string calldata employmentConfigId,
        address feeReceiver
    ) external view returns (uint256);

    /**
     * @notice Returns how much the fee is owed by <feeFraction, employmentAmount>.
     * @param employmentConfigId The employment config ID.
     * @param feeReceiver The fee receiver address.
     * @return The fee amount.
     */
    function getFeeAmount(
        string calldata employmentConfigId,
        address feeReceiver,
        uint256 employmentAmount
    ) external view returns (uint256);

    /**
     * @notice Return the employment config.
     * @param employmentConfigId The employment config ID.
     */
    function getEmploymentConfig(
        string calldata employmentConfigId
    ) external view returns (EmploymentConfig memory config);
}
