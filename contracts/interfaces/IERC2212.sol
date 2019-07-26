pragma solidity 0.5.10;

interface IERC2212 {
    /// @notice This emits when the `owner` whitelists a new cToken and its underlying.
    event WhitelistCToken(address indexed cTokenAddress, address underlyingAddress);

    /// @notice This emits when the `owner` discard a cToken.
    event DiscardCToken(address indexed cTokenAddress);

    /// @notice This emits when a new stake is created.
    event Stake(
        address indexed staker,
        address indexed cTokenAddress,
        address indexed underlyingAddress,
        bool converted,
        uint256 cTokenDeposit,
        uint256 exchangeRate
    );

    /// @notice This emits when either the staker or the `owner` redeems the stake. The deposit plus
    ///  any accrued interest is returned back to the staker and the `owner` withholds their fee.
    event Redeem(
        address indexed staker,
        address indexed cTokenAddress,
        address indexed underlyingAddress,
        uint256 cTokenFee,
        uint256 cTokenWithdrawal,
        uint256 exchangeRate
    );

    /// @notice This emits when the `owner` withdraws a portion or all of the accrued profits.
    event TakeEarnings(address indexed tokenAddress, uint256 indexed amount);

    /// @notice This emits when the `owner` updates the fee practiced by the contract.
    event UpdateFee(uint256 indexed fee);

    /// @notice Returns the owner of the contract.
    /// @dev This address can whitelist and discard cTokens and withdraw profits accrued over time.
    function owner() external view returns (address);

    /// @notice Returns the fee as a percentage value scaled by 1e18.
    function fee() external view returns (uint256);

    /// @notice Returns the stake that consists of the initial deposit plus the interest accrued over time.
    /// @dev Reverts if `staker` doesn't have an active stake. Reverts if `tokenAddress` doesn't match either
    ///  the cToken or the underlying of the stake.
    /// @param staker The address of the user that has an active stake.
    /// @param tokenAddress The address of either the cToken or the underlying of the stake.
    function balanceOf(address staker, address tokenAddress) external view returns (uint256);

    /// @notice Returns the initial deposit.
    /// @dev Reverts if `staker` doesn't have an active stake. Reverts if `tokenAddress` doesn't match either.
    ///  the cToken or the underlying of the stake.
    /// @param staker The address of the user that has an active stake.
    /// @param tokenAddress The address of either the cToken or the underlying of the stake.
    function depositOf(address staker, address tokenAddress) external view returns (uint256);

    /// @notice Whistelists a cToken to automatically convert its underlying when deposited.
    /// @dev Reverts if cToken is whitelisted. Reverts if `msg.sender` is not `owner`.
    /// @param cTokenAddress The address of the cToken.
    /// @param underlyingAddress The address of the cToken's underlying.
    function whitelistCToken(address cTokenAddress, address underlyingAddress) external;

    /// @notice Discards a cToken that has been whitelisted before.
    /// @dev Reverts if token is not whitelisted. Reverts if `msg.sender` is not `owner`.
    /// @param cTokenAddress The address of the cToken to discard.
    function discardCToken(address cTokenAddress) external;

    /// @notice Resets the allowance granted to the cToken contract to spend from the underlying contract.
    /// @dev Anyone can call this function.
    /// @param cTokenAddress The address of the cToken.
    /// @param underlyingAddress The address of the cToken's underlying.
    function resetAllowance(address cTokenAddress, address underlyingAddress) external;

    /// @notice Creates a new stake object for `msg.sender`. It automatically converts an underlying to
    ///  its cToken form so that the contract can earn interest.
    /// @dev Reverts if `msg.sender` already has an active stake. Reverts if the cToken/ underlying pair has not been whitelisted.
    /// @param tokenAddress The address of either the cToken or the underlying.
    /// @param amount The amount of tokens to deposit.
    function stake(address tokenAddress, uint256 amount) external;

    /// @notice Returns the deposit plus any accrued interest to the staker and takes the fee for the `owner`.
    /// @dev Note that the fee can only be levied on the accrued interest, never on the base deposit.
    ///  Reverts if `msg.sender` is not the staker or the `owner`.
    /// @param staker The address for whom to redeem the stake.
    function redeem(address staker) external;

    /// @notice Withdraws the earnings accrued over time to owner.
    /// @dev Reverts if `amount` is more than what's available. Reverts if `msg.sender` is not `owner`.
    /// @param tokenAddress The address of the currency for which to withdraw the funds.
    /// @param amount The amount of funds to withdraw.
    function takeEarnings(address tokenAddress, uint256 amount) external;

    /// @notice Updates the fee practiced by the contract.
    /// @dev Reverts if `msg.sender` is not `owner`.
    /// @param newFee The new fee practiced by the contract. Has to be a percentage value scaled by 1e18. Can be anything between 0% and 100%.
    function updateFee(uint256 newFee) external;
}
