// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

/**
 * @title ISkillsHub
 * @notice This is the interface for the EmployWithConfig contract.
 */

interface ISkillsHub {
    struct Employment {
        address employer;
        address developer;
        address token;
        uint256 amount;
        uint256 claimedAmount;
        uint256 time;
        uint256 startTime;
        uint256 endTime;
    }

    /**
     * @notice Initialize the contract, setting web3Entry address.
     * @param feeReceiver_ Address of web3Entry.
     */
    function initialize(address feeReceiver_) external;

    /**
     * @notice Sets the fee percentage of specific receiver.
     * @param feeReceiver The fee receiver address.
     * @param fraction The percentage measured in basis points. Each basis point represents 0.01%.
     */
    function setFeeFraction(address feeReceiver, uint256 fraction) external;

    /**
     * @notice Start the employment of specific employment id. <br>
     * Emits a {StartEmployment} event.
     * @param develper The developer address.
     * @param token The token address.
     * @param amount The amount of token.
     * @param time The time of employment.
     * @param deadline The deadline of employment.
     * @param signature The signature of the message.
     */
    function startEmployment(
        address develper,
        address token,
        uint256 amount,
        uint256 time,
        uint256 deadline,
        bytes memory signature
    ) external;

    /**
     * @notice Extends the employment config of specific employment id. <br>
     * Emits a {ExtendEmployment} event.
     * @dev It will try to collect the employment first, and then update the employment config.
     * @param employmentId The employment config ID to update.
     * @param extendTime The extend time of employment.
     */
    function extendEmployment(
        uint256 employmentId,
        uint256 extendTime
    ) external;

    /**
     * @notice Cancels the employment. <br>
     * Emits a {CancelEmployment} event.
     * @dev It will try to collect the remaining assets first, and then delete the employment config.
     * @dev Only the employment creator can cancel the employment.
     * @param employmentId The employment config ID to cancel.
     */
    function cancelEmployment(uint256 employmentId) external;

    /**
     * @notice Claims all unredeemed salary from the contract to developer address. <br>
     * Emits a {ClaimEmployment} event if claims successfully.
     * @dev It will transfer all unredeemed token from the contract to the `developer`.
     * @param employmentId The employment config ID.
     */
    function claimFund(uint256 employmentId) external;

    /**
     * @notice Returns the fee percentage of specific <receiver, employment>.
     * @dev It will return the first non-zero value by priority feeFraction4Character and defaultFeeFraction.
     * @return fraction The percentage measured in basis points. Each basis point represents 0.01%.
     */
    function getFeeFraction() external view returns (uint256);

    /**
     * @notice Returns how much the fee is owed by <feeFraction, employmentAmount>.
     * @param amount The employment amount.
     * @return The fee amount.
     */
    function getFeeAmount(uint256 amount) external view returns (uint256);

    /**
     * @notice Return the employment config.
     * @param employmentId The employment config ID.
     */
    function getEmploymentInfo(
        uint256 employmentId
    ) external view returns (Employment memory employment);

    /**
     * @notice Returns the available fund of specific <employment, claimTimestamp>.
     * @dev It will return the available fund of specific employment.
     * @param employmentId The employment ID.
     * @return The available fund.
     */
    function getAvailableFund(uint256 employmentId) external view returns (uint256);

    /**
     * @notice Returns the claimed fund of specific employment.
     * @dev It will return the claimed fund of specific employment.
     * @param employmentId The employment config ID.
     * @return The claimed fund.
     */
    function getClaimedFund(uint256 employmentId) external view returns (uint256);

    /**
     * @notice Returns the current employment index.
     * @dev It will return the current employment index.
     * @return The current employment index.
     */
    function getCurrentEmploymentIndex() external view returns (uint256);
}
