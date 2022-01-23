// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

// Source: https://github.com/ZeframLou/playpen/blob/2eb6ff4722e8d8d6ef3a40629e985ce9eb99487e/src/test/base/BaseTest.sol

import {DSTest} from "ds-test/test.sol";

import {IVM} from "../utils/IVM.sol";

contract BaseTest is DSTest {
    IVM internal constant VM = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
}
