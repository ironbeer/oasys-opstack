// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

/// @title IL1UpgradeImplementer
/// @notice L1 Upgrade implementer interface
interface IL1UpgradeImplementer {
    /// @notice Gets the original ProxyAdmin owner
    /// @param _chainId Chain identifier
    /// @return Original owner address
    function getOriginalProxyAdminOwner(uint256 _chainId) external view returns (address);

    /// @notice Execute a step in the upgrade process
    /// @dev Can only be called by the UpgradeManager contract
    /// @param _chainId The chain ID of the verse network being upgraded
    /// @param _nextStep The next step number to execute in the upgrade sequence
    /// @return completed True if the step was completed successfully
    function execute(uint256 _chainId, uint8 _nextStep) external returns (bool completed);
}
