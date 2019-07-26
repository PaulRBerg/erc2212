pragma solidity 0.5.10;

/// @title CErc20 interface
/// @author Paul Berg - <hello@paulrberg.com>
/// @dev See https://compound.finance/developers

interface CErc20Interface {
    function approve(address spender, uint256 value) external returns (bool);
    function exchangeRateCurrent() external returns (uint256);
    function mint(uint256 mintAmount) external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}
