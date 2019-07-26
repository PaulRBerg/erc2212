/* global describe, it */
const BigNumber = require("bignumber.js");
const truffleAssert = require("truffle-assertions");
// const {time} = require("openzeppelin-test-helpers");

const constants = require("../constants");

const CErc20 = artifacts.require("CErc20Mock");
CErc20.numberFormat = "BigNumber";

module.exports = function(owner, recipient, someone) {
  describe("cTokens", function() {
    it("...should whitelist cToken", async function() {
      const someOtherCToken = await CErc20.new(this.token.address, "Compound DAI v2", "cDAI v2", 8);
      await this.erc2212.whitelistCToken(someOtherCToken.address, this.token.address);
      const resolvedCTokenAddress = await this.erc2212.cTokenList("1");
      resolvedCTokenAddress.should.be.equal(someOtherCToken.address);
    });

    it("...should fail to whitelist cToken if not owner", async function() {
      const someOtherCToken = await CErc20.new(this.token.address, "Compound DAI v2", "cDAI v2", 8);
      await truffleAssert.fails(
        this.erc2212.whitelistCToken(someOtherCToken.address, this.token.address, {from: someone}),
        "caller is not the owner",
      );
    });

    it("...should discard cToken", async function() {
      await this.erc2212.discardCToken(this.cToken.address);
      await truffleAssert.fails(this.erc2212.cTokenList("0"), truffleAssert.ErrorType.INVALID_OPCODE);
    });

    it("...should fail to discard cToken if not owner", async function() {
      await truffleAssert.fails(
        this.erc2212.discardCToken(this.cToken.address, {from: someone}),
        "caller is not the owner",
      );
    });
  });

  describe("business", function() {
    it("...should set fee", async function() {
      await this.erc2212.updateFee(constants.FEE_MANTISSA.toString(10));
      const resolvedFee = await this.erc2212.fee();
      resolvedFee.should.be.bignumber.equal(constants.FEE_MANTISSA);
    });

    it("...should fail to set fee if not owner", async function() {
      await truffleAssert.fails(
        this.erc2212.updateFee(constants.FEE_MANTISSA, {from: someone}),
        "caller is not the owner",
      );
    });
  });

  describe("stakes", function() {
    it("...should stake underlying", async function() {
      await this.token.approve(this.erc2212.address, constants.MAX_ALLOWANCE);

      const stakeAmount = new BigNumber(1000).multipliedBy(1e18);
      const exchangeRate = new BigNumber(await this.cToken.contract.methods.exchangeRateCurrent().call());
      const cTokenDeposit = stakeAmount.multipliedBy(exchangeRate).dividedBy(1e18);

      await this.erc2212.stake(this.token.address, stakeAmount.toString(10));
      const stake = await this.erc2212.stakes(owner);
      stake.exchangeRate.should.be.bignumber.equal(exchangeRate);
      stake.converted.should.be.equal(true);
      stake.cTokenAddress.should.be.equal(this.cToken.address);
      stake.cTokenDeposit.should.be.bignumber.equal(cTokenDeposit);
      stake.underlyingAddress.should.be.equal(this.token.address);
    });

    it("...should fail to stake underlying if insufficient allowance", async function() {
      const stakeAmount = new BigNumber(1000).multipliedBy(1e18);
      await truffleAssert.fails(
        this.erc2212.stake(this.token.address, stakeAmount.toString(10)),
        "contract not allowed to transfer enough tokens",
      );
    });

    it("...should redeem underlying", async function() {});

    it("...should fail to redeem underlying", async function() {});

    it("...should stake cTokens", async function() {
      const tokenAmount = new BigNumber(1000).multipliedBy(1e18);
      const exchangeRate = new BigNumber(await this.cToken.contract.methods.exchangeRateCurrent().call());
      const stakeAmount = tokenAmount.multipliedBy(exchangeRate).dividedBy(1e18);

      await this.token.approve(this.cToken.address, constants.MAX_ALLOWANCE);
      await this.cToken.mint(tokenAmount.toString(10));
      await this.cToken.approve(this.erc2212.address, constants.MAX_ALLOWANCE);

      await this.erc2212.stake(this.cToken.address, stakeAmount.toString(10));
      const stake = await this.erc2212.stakes(owner);
      stake.exchangeRate.should.be.bignumber.equal(exchangeRate);
      stake.converted.should.be.equal(false);
      stake.cTokenAddress.should.be.equal(this.cToken.address);
      stake.cTokenDeposit.should.be.bignumber.equal(stakeAmount);
      stake.underlyingAddress.should.be.equal(this.token.address);
    });

    it("...should fail to stake cTokens if insufficient allowance", async function() {
      const tokenAmount = new BigNumber(1000).multipliedBy(1e18);
      const exchangeRate = new BigNumber(await this.cToken.contract.methods.exchangeRateCurrent().call());
      const stakeAmount = tokenAmount.multipliedBy(exchangeRate).dividedBy(1e18);

      await this.token.approve(this.cToken.address, constants.MAX_ALLOWANCE);
      await this.cToken.mint(tokenAmount.toString(10));

      await truffleAssert.fails(
        this.erc2212.stake(this.cToken.address, stakeAmount.toString(10)),
        "contract not allowed to transfer enough tokens",
      );
    });

    it("...should redeem cTokens", async function() {});

    it("...should fail to redeem cTokens", async function() {});
  });
};
