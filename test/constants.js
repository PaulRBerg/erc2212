const BigNumber = require("bignumber.js");

module.exports = {
  FEE_MANTISSA: new BigNumber("0.2").multipliedBy(1e18),
  MAX_ALLOWANCE: "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
};
