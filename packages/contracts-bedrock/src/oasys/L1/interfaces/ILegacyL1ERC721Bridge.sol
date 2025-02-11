// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:legacy
/// @title ILegacyL1ERC721Bridge
/// @notice The interface of the legacy L1ERC721Bridge implemented by Oasys.
///         https://github.com/oasysgames/oasys-optimism/blob/4d667a1/packages/contracts/contracts/oasys/L1/messaging/IL1ERC721Bridge.sol
interface ILegacyL1ERC721Bridge {
    event ERC721DepositInitiated(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _tokenId,
        bytes _data
    );

    event ERC721WithdrawalFinalized(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _tokenId,
        bytes _data
    );

    /**
     * @dev get the address of the corresponding L2 ERC721 bridge contract.
     * @return Address of the corresponding L2 ERC721 bridge contract.
     */
    function l2ERC721Bridge() external returns (address);

    /**
     * @dev deposit the token of ERC721 to the caller on L2.
     * @param _l1Token Address of the L1 ERC721 we are depositing
     * @param _l2Token Address of the L1 respective L2 ERC721
     * @param _tokenId Token Id of the ERC721 to deposit
     * @param _l2Gas Gas limit required to complete the deposit on L2.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function depositERC721(
        address _l1Token,
        address _l2Token,
        uint256 _tokenId,
        uint32 _l2Gas,
        bytes calldata _data
    )
        external;

    /**
     * @dev deposit the token of ERC721 to a recipient on L2.
     * @param _l1Token Address of the L1 ERC721 we are depositing
     * @param _l2Token Address of the L1 respective L2 ERC721
     * @param _to L2 address to credit the withdrawal to.
     * @param _tokenId Token Id of the ERC721 to deposit.
     * @param _l2Gas Gas limit required to complete the deposit on L2.
     * @param _data Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function depositERC721To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _tokenId,
        uint32 _l2Gas,
        bytes calldata _data
    )
        external;

    /**
     * @dev Complete a withdrawal from L2 to L1,
     * and transfer to the recipient of the L1 ERC721 token.
     * This call will fail if the initialized withdrawal from L2 has not been finalized.
     *
     * @param _l1Token Address of L1 token to finalizeWithdrawal for.
     * @param _l2Token Address of L2 token where withdrawal was initiated.
     * @param _from L2 address initiating the transfer.
     * @param _to L1 address to credit the withdrawal to.
     * @param _tokenId Token Id of the ERC721 to deposit.
     * @param _data Data provided by the sender on L2. This data is provided
     *   solely as a convenience for external contracts. Aside from enforcing a maximum
     *   length, these contracts provide no guarantees about its content.
     */
    function finalizeERC721Withdrawal(
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    )
        external;
}
