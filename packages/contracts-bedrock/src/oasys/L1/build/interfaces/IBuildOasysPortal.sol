// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IBuildOasysPortal {
    /// @notice The create2 salt used for deployment of the contract implementations.
    /// @param _l2Oracle Address of the L2OutputOracle contract.
    /// @param _guardian Address that can pause withdrawals.
    /// @param _systemConfig Address of the SystemConfig contract.
    function deployBytecode(
        address _l2Oracle,
        address _guardian,
        address _systemConfig
    )
        external
        pure
        returns (bytes memory);

    /// @notice Return data for initializer.
    /// @param _paused Sets the contract's pausability state.
    /// @param relayer Sets the messager relayer
    function initializeData(bool _paused, address relayer) external pure returns (bytes memory);
}
