pragma solidity 0.5.10;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "./compound/ErrorReporter.sol";
import "./compound/Exponential.sol";

import "./interfaces/CErc20Interface.sol";
import "./interfaces/IERC2212.sol";
import "./Types.sol";

contract ERC2212 is IERC2212, Ownable, Exponential, TokenErrorReporter {
    using SafeMath for uint256;

    event DiscardCToken(address indexed cTokenAddress);
    event Redeem(
        address indexed staker,
        address indexed cTokenAddress,
        address indexed underlyingAddress,
        uint256 cTokenFee,
        uint256 cTokenWithdrawal,
        uint256 exchangeRate
    );
    event Stake(
        address indexed staker,
        address indexed cTokenAddress,
        address indexed underlyingAddress,
        bool converted,
        uint256 cTokenDeposit,
        uint256 exchangeRate
    );
    event TakeEarnings(address indexed tokenAddress, uint256 indexed amount);
    event UpdateFee(uint256 indexed fee);
    event WhitelistCToken(address indexed cTokenAddress, address underlyingAddress);

    uint256 constant EXP_SCALE = 1e18;
    uint256 public constant MAX_ALLOWANCE = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    uint256 public earnings;
    Exp public feeExp;
    address[] public cTokenList;
    mapping(address => Types.cToken) public cTokenStructs;
    mapping(address => Types.Stake) public stakes;

    constructor(uint256 feeMantissa, address[] memory cTokenAddresses, address[] memory underlyingAddresses) public {
        feeExp = Exp({mantissa: feeMantissa});
        require(cTokenAddresses.length == underlyingAddresses.length, "array lengths do not match");
        uint256 length = cTokenAddresses.length;
        for (uint256 i = 0; i < length; i = i.add(1)) {
            whitelistCToken(cTokenAddresses[i], underlyingAddresses[i]);
        }
    }

    modifier onlyStakerOrOwner(address staker) {
        require(msg.sender == staker || owner() == staker, "caller is not the staker or the owner");
        _;
    }

    modifier stakeExists(address staker) {
        require(stakes[staker].isEntity, "stake doesn't exist");
        _;
    }

    function balanceOf(address staker, address tokenAddress) public view stakeExists(staker) returns (uint256 balance) {
        Types.Stake memory memStake = stakes[staker];
        if (tokenAddress == memStake.cTokenAddress) {
            // TODO: subtract fee
            return memStake.cTokenDeposit;
        } else if (tokenAddress == memStake.underlyingAddress) {
            // TODO: compute this and subtract fee
            return 0;
        } else {
            revert("token address is not the cToken or the underlying of the stake");
        }
    }

    function depositOf(address staker, address tokenAddress) public view stakeExists(staker) returns (uint256 deposit) {
        Types.Stake memory memStake = stakes[staker];
        if (tokenAddress == memStake.cTokenAddress) {
            return memStake.cTokenDeposit;
        } else if (tokenAddress == memStake.underlyingAddress) {
            // TODO: compute this
            return 0;
        } else {
            revert("token address is not the cToken or the underlying of the stake");
        }
    }

    function fee() public view returns (uint256) {
        return feeExp.mantissa;
    }

    function isCToken(address tokenAddress) public view returns (bool isIndeed) {
        if (cTokenList.length == uint256(Error.NO_ERROR)) return false;
        return (cTokenList[cTokenStructs[tokenAddress].listPointer] == tokenAddress);
    }

    function isStake(address staker) public view returns (bool isIndeed) {
        return stakes[staker].isEntity;
    }

    function isUnderlying(address tokenAddress) public view returns (int256 index) {
        if (cTokenList.length == uint256(Error.NO_ERROR)) return -1;
        uint256 length = cTokenList.length;
        for (uint256 i = 0; i < length; i = i.add(1)) {
            if (tokenAddress == cTokenStructs[cTokenList[i]].underlyingAddress) {
                return int256(i);
            }
        }
        return -1;
    }

    function whitelistCToken(address cTokenAddress, address underlyingAddress) public onlyOwner {
        require(!isCToken(cTokenAddress), "ctoken already exists");
        cTokenStructs[cTokenAddress].underlyingAddress = underlyingAddress;
        cTokenStructs[cTokenAddress].listPointer = cTokenList.push(cTokenAddress).sub(1);
        resetAllowance(cTokenAddress, underlyingAddress);
        emit WhitelistCToken(cTokenAddress, underlyingAddress);
    }

    function discardCToken(address cTokenAddress) public onlyOwner {
        require(isCToken(cTokenAddress), "ctoken doesn't exist");
        uint256 rowToDelete = cTokenStructs[cTokenAddress].listPointer;
        address keyToMove = cTokenList[cTokenList.length.sub(1)];
        cTokenList[rowToDelete] = keyToMove;
        cTokenStructs[keyToMove].listPointer = rowToDelete;
        cTokenList.length = cTokenList.length.sub(1);
        emit DiscardCToken(cTokenAddress);
    }

    function resetAllowances() public onlyOwner {
        uint256 length = cTokenList.length;
        for (uint256 i = 0; i < length; i = i.add(1)) {
            resetAllowance(cTokenList[i], cTokenStructs[cTokenList[i]].underlyingAddress);
        }
    }

    function resetAllowance(address cTokenAddress, address underlyingAddress) public onlyOwner {
        IERC20 underlyingContract = IERC20(underlyingAddress);
        require(underlyingContract.approve(cTokenAddress, MAX_ALLOWANCE));
    }

    function stake(address tokenAddress, uint256 amount) public {
        require(!isStake(msg.sender), "user is already staking");
        IERC20 token = IERC20(tokenAddress);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= amount, "contract not allowed to transfer enough tokens");
        require(token.transferFrom(msg.sender, address(this), amount), "token transfer failed");

        if (isCToken(tokenAddress)) {
            addStakeForCToken(tokenAddress, amount);
        } else {
            int256 index = isUnderlying(tokenAddress);
            require(index > -1, "token address not whitelisted");
            addStakeForUnderlying(cTokenList[uint256(index)], amount);
        }
    }

    // TODO: this doesn't work properly, should switch to Exponenial calculations
    function redeem(address staker) public onlyStakerOrOwner(staker) {
        Types.Stake memory memStake = stakes[msg.sender];
        CErc20Interface cTokenContract = CErc20Interface(memStake.cTokenAddress);
        uint256 exchangeRateCurrent = cTokenContract.exchangeRateCurrent();
        uint256 exchangeRateRatio = exchangeRateCurrent.div(memStake.exchangeRate);
        uint256 cTokenDepositParity = memStake.cTokenDeposit.div(exchangeRateRatio);
        uint256 cTokenFee = memStake.cTokenDeposit.sub(cTokenDepositParity).mul(feeExp.mantissa).div(EXP_SCALE);
        uint256 cTokenWithdrawal = memStake.cTokenDeposit.sub(cTokenFee);
        earnings = earnings.add(cTokenFee);

        delete stakes[msg.sender];
        emit Redeem(
            msg.sender,
            memStake.cTokenAddress,
            memStake.underlyingAddress,
            cTokenFee,
            cTokenWithdrawal,
            exchangeRateCurrent
        );
        if (!memStake.converted) {
            require(CErc20Interface(memStake.cTokenAddress).transfer(msg.sender, cTokenWithdrawal));
        } else {
            require(cTokenContract.redeem(cTokenWithdrawal) == uint256(Error.NO_ERROR), "underlying redeeming failed");
            (CarefulMath.MathError mathErr, uint256 underlyingWithdrawal) = divScalarByExpTruncate(
                cTokenWithdrawal,
                Exp({mantissa: exchangeRateCurrent})
            );
            require(IERC20(memStake.underlyingAddress).transfer(msg.sender, underlyingWithdrawal));
        }
    }

    // TODO
    function takeEarnings(address tokenAddress, uint256 amount) public onlyOwner {
        emit TakeEarnings(tokenAddress, amount);
        require(IERC20(tokenAddress).transfer(msg.sender, amount));
    }

    function updateFee(uint256 newFee) public onlyOwner {
        feeExp = Exp({mantissa: newFee});
        emit UpdateFee(newFee);
    }

    function addStakeForCToken(address cTokenAddress, uint256 amount) internal {
        CErc20Interface cTokenContract = CErc20Interface(cTokenAddress);
        bool converted = false;
        uint256 cTokenDeposit = amount;
        uint256 exchangeRate = cTokenContract.exchangeRateCurrent();
        address underlyingAddress = cTokenStructs[cTokenAddress].underlyingAddress;
        stakes[msg.sender] = Types.Stake({
            converted: converted,
            cTokenAddress: cTokenAddress,
            cTokenDeposit: cTokenDeposit,
            exchangeRate: exchangeRate,
            isEntity: true,
            underlyingAddress: underlyingAddress
        });
        emit Stake(msg.sender, cTokenAddress, underlyingAddress, converted, cTokenDeposit, exchangeRate);
    }

    function addStakeForUnderlying(address cTokenAddress, uint256 amount) internal {
        CErc20Interface cTokenContract = CErc20Interface(cTokenAddress);
        uint256 exchangeRate = cTokenContract.exchangeRateCurrent();
        (CarefulMath.MathError mathErr, uint256 cTokenDeposit) = divScalarByExpTruncate(
            amount,
            Exp({mantissa: exchangeRate})
        );
        require(mathErr == MathError.NO_ERROR, "mint exchange calculation failed");
        require(cTokenContract.mint(amount) == uint256(Error.NO_ERROR), "ctoken conversion failed");

        bool converted = true;
        address underlyingAddress = cTokenStructs[cTokenAddress].underlyingAddress;
        stakes[msg.sender] = Types.Stake({
            converted: converted,
            cTokenAddress: cTokenAddress,
            cTokenDeposit: cTokenDeposit,
            exchangeRate: exchangeRate,
            isEntity: true,
            underlyingAddress: underlyingAddress
        });
        emit Stake(msg.sender, cTokenAddress, underlyingAddress, converted, cTokenDeposit, exchangeRate);
    }
}
