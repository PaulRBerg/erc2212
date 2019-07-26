/* global artifacts, contract */
const BigNumber = require("bignumber.js");

const shouldBehaveLikeerc2212 = require("./ERC2212.behavior");

const CErc20 = artifacts.require("CErc20Mock");
const ERC20 = artifacts.require("ERC20Mock");
const erc2212 = artifacts.require("ERC2212");

CErc20.numberFormat = "BigNumber";
ERC20.numberFormat = "BigNumber";
erc2212.numberFormat = "BigNumber";

contract("erc2212", function([owner, recipient, someone]) {
  beforeEach(async function() {
    this.token = await ERC20.new("Dai", "DAI", 18);
    const initialBalance = new BigNumber(1000000).multipliedBy(1e18);
    await this.token.mint(owner, initialBalance.toString(10));
    this.cToken = await CErc20.new(this.token.address, "Compound DAI", "cDAI", 8);
    const feeMantissa = new BigNumber(0.2).multipliedBy(1e18);
    this.erc2212 = await erc2212.new(feeMantissa.toString(10), [this.cToken.address], [this.token.address]);
  });

  shouldBehaveLikeerc2212(owner, recipient, someone);
});
