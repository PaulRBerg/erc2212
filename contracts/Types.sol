pragma solidity 0.5.10;

library Types {
    struct cToken {
        uint256 listPointer;
        address underlyingAddress;
    }
    struct Stake {
        bool converted;
        address cTokenAddress;
        uint256 cTokenDeposit;
        uint256 exchangeRate;
        bool isEntity;
        address underlyingAddress;
    }
}
