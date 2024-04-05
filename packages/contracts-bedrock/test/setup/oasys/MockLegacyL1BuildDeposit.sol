// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

contract MockLegacyL1BuildDeposit {
    mapping(address => uint256) public _buildBlock;

    function setBuildBlock(address _builder, uint256 blockNumber) public {
        _buildBlock[_builder] = blockNumber;
    }

    function getBuildBlock(address _builder) public view returns (uint256) {
        return _buildBlock[_builder];
    }
}
