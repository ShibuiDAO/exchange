pragma solidity ^0.8.6;

import {DSTest} from "ds-test/test.sol";

import {IVM} from "../utils/IVM.sol";

contract BaseTest is DSTest {
    IVM internal constant VM = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
}
