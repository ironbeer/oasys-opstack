// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Openzeppelin Libraries
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { ISemver } from "src/universal/ISemver.sol";
import { IL1BuildAgent } from "src/oasys/L1/build/interfaces/IL1BuildAgent.sol";
import { IL1UpgradeManager } from "src/oasys/L1/upgrade/IL1UpgradeManager.sol";
import { IL1UpgradeImplementer } from "src/oasys/L1/upgrade/IL1UpgradeImplementer.sol";

import { ProxyAdmin } from "src/universal/ProxyAdmin.sol";
import { StorageSetter } from "src/universal/StorageSetter.sol";

/// @custom:proxied
/// @title L1UpgradeManager
/// @dev This contract is intended to be proxied
contract L1UpgradeManager is IERC165, ISemver, IL1UpgradeManager, Ownable {
    /// @notice Emitted when an upgrade step is executed
    /// @param currentImplementer Index of the current implementer
    /// @param step Current step number
    /// @param completed Whether the upgrade process is completed
    event Advanced(uint8 indexed currentImplementer, uint8 step, bool completed);

    /// @dev Tracks the status of an upgrade for each chain
    struct Status {
        uint8 currentImplementer; // Current implementer index
        uint8 nextStep; // Next step to execute
    }

    /// @inheritdoc IL1UpgradeManager
    StorageSetter public immutable storageSetter;

    /// @inheritdoc IL1UpgradeManager
    IL1BuildAgent public immutable buildAgent;

    // List of upgrade implementers
    IL1UpgradeImplementer[] public implementers;

    // List of upgrade status for each L2 Chain ID
    mapping(uint256 => Status) public statuses;

    /// @dev Ensures the caller is the designated builder for the chain
    modifier onlyBuilder(uint256 _chainId) {
        address builder = buildAgent.getBuilderInternally(_chainId);
        require(msg.sender == builder, "L1UpgradeManager: inconsistent builder");
        _;
    }

    /// @dev Ensures the caller is the current implementer for the chain
    modifier onlyCurrentImplementer(uint256 _chainId) {
        require(
            msg.sender == address(_getImplementer(statuses[_chainId].currentImplementer)),
            "L1UpgradeManager: inconsistent implementer"
        );
        _;
    }

    /// @notice Initializes the upgrade manager
    /// @param _owner Address that will own this contract
    /// @param _buildAgent Address of the BuildAgent contract
    /// @param _firstImplementer Address of the first upgrade implementer
    constructor(address _owner, address _buildAgent, address _firstImplementer) {
        require(_owner != address(0), "L1UpgradeManager: owner is zero address");
        transferOwnership(_owner);

        require(_buildAgent != address(0), "L1UpgradeManager: buildAgent is zero address");
        buildAgent = IL1BuildAgent(_buildAgent);

        storageSetter = new StorageSetter();
        _addNextImplementer(_firstImplementer);
    }

    /// @notice Semantic version.
    /// @custom:semver 1.0.0
    function version() public pure virtual returns (string memory) {
        return "1.0.0";
    }

    /// @notice Checks if the contract supports an interface.
    ///         Expected to be called from implementer contracts
    /// @param _interfaceId Interface identifier to check
    function supportsInterface(bytes4 _interfaceId) public pure override(IERC165) returns (bool) {
        return _interfaceId == type(IL1UpgradeManager).interfaceId || _interfaceId == type(IERC165).interfaceId;
    }

    /// @notice Add a new implementer to the manager
    /// @param _implementer Address of the new implementer
    function addNextImplementer(address _implementer) external onlyOwner {
        _addNextImplementer(_implementer);
    }

    /// @notice Executes the next upgrade step for a chain
    /// @param _chainId ID of the chain to upgrade
    function execute(uint256 _chainId) external onlyBuilder(_chainId) {
        Status storage status = statuses[_chainId];
        IL1UpgradeImplementer implementer = _getImplementer(status.currentImplementer);

        bool completed = implementer.execute(_chainId, status.nextStep);
        if (completed) {
            status.currentImplementer += 1;
            status.nextStep = 0;
            _releaseProxyAdminOwnership(_chainId, implementer);
        } else {
            status.nextStep += 1;
        }
    }

    /// @notice Releases the ownership of the ProxyAdmin for the specified chain to the original owner
    /// @param _chainId Chain identifier
    function releaseProxyAdminOwnership(uint256 _chainId) external onlyBuilder(_chainId) {
        Status storage status = statuses[_chainId];
        IL1UpgradeImplementer implementer = _getImplementer(status.currentImplementer);
        _releaseProxyAdminOwnership(_chainId, implementer);
    }

    /// @dev Internal function to release ProxyAdmin ownership
    function _releaseProxyAdminOwnership(uint256 _chainId, IL1UpgradeImplementer _implementer) internal {
        proxyAdmin(_chainId).transferOwnership(_implementer.getOriginalProxyAdminOwner(_chainId));
    }

    /// @inheritdoc IL1UpgradeManager
    function proxyAdmin(uint256 _chainId) public view returns (ProxyAdmin) {
        (address _proxyAdmin,,,,,,,,) = buildAgent.builtLists(_chainId);
        return ProxyAdmin(_proxyAdmin);
    }

    /// @inheritdoc IL1UpgradeManager
    function upgrade(
        uint256 _chainId,
        address _proxy,
        address _implementation
    )
        external
        onlyCurrentImplementer(_chainId)
    {
        _upgrade(_chainId, _proxy, _implementation, new bytes(0));
    }

    /// @inheritdoc IL1UpgradeManager
    function upgrade(
        uint256 _chainId,
        address _proxy,
        address _implementation,
        StorageUpdate memory _storageUpdate
    )
        external
        onlyCurrentImplementer(_chainId)
    {
        _upgrade(_chainId, _proxy, _implementation, new bytes(0), _storageUpdate);
    }

    /// @inheritdoc IL1UpgradeManager
    function upgradeAndCall(
        uint256 _chainId,
        address _proxy,
        address _implementation,
        bytes memory _data
    )
        external
        onlyCurrentImplementer(_chainId)
    {
        _upgrade(_chainId, _proxy, _implementation, _data);
    }

    /// @inheritdoc IL1UpgradeManager
    function upgradeAndCall(
        uint256 _chainId,
        address _proxy,
        address _implementation,
        bytes memory _data,
        StorageUpdate memory _storageUpdate
    )
        external
        onlyCurrentImplementer(_chainId)
    {
        _upgrade(_chainId, _proxy, _implementation, _data, _storageUpdate);
    }

    /// @dev Adds a new implementer after validating its interface
    function _addNextImplementer(address _implementer) internal {
        require(
            ERC165Checker.supportsInterface(_implementer, type(IL1UpgradeImplementer).interfaceId),
            "L1UpgradeManager: Implementer must support IL1UpgradeImplementer"
        );
        implementers.push(IL1UpgradeImplementer(_implementer));
    }

    /// @dev Retrieves an implementer by index with bounds checking
    function _getImplementer(uint8 _index) internal view returns (IL1UpgradeImplementer) {
        require(_index < implementers.length, "L1UpgradeManager: Out of bounds");
        return implementers[_index];
    }

    /// @notice Upgrades a proxy contract implementation
    function _upgrade(uint256 _chainId, address _proxy, address _implementation, bytes memory _data) internal {
        require(_implementation != address(0), "L1UpgradeManager: implementation is zero address");

        if (_data.length == 0) {
            proxyAdmin(_chainId).upgrade({ _proxy: payable(_proxy), _implementation: _implementation });
        } else {
            proxyAdmin(_chainId).upgradeAndCall({
                _proxy: payable(_proxy),
                _implementation: _implementation,
                _data: _data
            });
        }
    }

    /// @notice Upgrades a proxy contract implementation with storage modification
    function _upgrade(
        uint256 _chainId,
        address _proxy,
        address _implementation,
        bytes memory _data,
        StorageUpdate memory _storageUpdate
    )
        internal
    {
        // Temporarily upgrades to StorageSetter
        _upgrade(_chainId, _proxy, address(storageSetter), new bytes(0));

        // Check if the current slot value matches the expected value
        bytes32 actual = StorageSetter(_proxy).getBytes32(_storageUpdate.slot);
        require(actual == _storageUpdate.currentValue, "L1UpgradeManager: unexpected slot value");

        // Updates the storage slot with the new value
        StorageSetter(_proxy).setBytes32(_storageUpdate.slot, _storageUpdate.newValue);

        // Upgrade to the new implementation
        _upgrade(_chainId, _proxy, _implementation, _data);
    }
}
