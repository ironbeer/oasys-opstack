// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

contract MockLegacyL1BuildAgent {
    mapping(uint256 => address) public addressManagers;
    address[] private _builders;
    uint256[] private _chainIds;
    function setAddressManager(uint256 _chainId, address _addressManager) public {
        addressManagers[_chainId] = _addressManager;
    }
    function getAddressManager(uint256 _chainId) public view returns (address) {
        return addressManagers[_chainId];
    }
    function setBuilder(address _builder, uint256 _chainId) public {
        _builders.push(_builder);
        _chainIds.push(_chainId);
    }
    function getBuilts(uint256 cursor, uint256 howMany)
        external
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256
        )
    {
        uint256 length = _builders.length;
        if (cursor + howMany >= length) {
            howMany = length - cursor;
        }
        address[] memory builders = new address[](howMany);
        uint256[] memory chainIds = new uint256[](howMany);
        for (uint256 i = 0; i < howMany; i++) {
            builders[i] = _builders[cursor + i];
            chainIds[i] = _chainIds[cursor + i];
        }
        return (builders, chainIds, cursor + howMany);
    }
}