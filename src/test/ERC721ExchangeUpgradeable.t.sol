pragma solidity ^0.8.11;

import {BaseTest} from "./base/BaseTest.sol";

import {IHevm} from "./utils/IHevm.sol";
import {IERC721Exchange} from "../contracts/interfaces/IERC721Exchange.sol";

contract ERC721ExchangeUpgradeableTest is BaseTest {
	IERC721Exchange internal erc721Exchange;
	IERC721Exchange internal erc721ExchangeUpgraded;

	function setUp() public {
		string[] memory deploymentAddressCommand = new string[](2);
		deploymentAddressCommand[0] = "cat";
		deploymentAddressCommand[1] = ".shibui/deployments";

		bytes memory deploymentAddresses = VM.ffi(deploymentAddressCommand);
		(address _erc721exchange, address _erc721exchangeUpgeaded) = abi.decode(deploymentAddresses, (address, address));

		erc721Exchange = IERC721Exchange(_erc721exchange);
		erc721ExchangeUpgraded = IERC721Exchange(_erc721exchangeUpgeaded);
	}

	function testDeploymentVersion() public {
		(uint256 major, uint256 minor, uint256 patch) = abi.decode(erc721Exchange.version(), (uint256, uint256, uint256));

		assertEq(major, 1);
		assertEq(minor, 0);
		assertEq(patch, 3);
	}

	function testDeploymentUpgradeVersion() public {
		(uint256 _major, uint256 _minor, uint256 _patch) = abi.decode(erc721Exchange.version(), (uint256, uint256, uint256));
		(uint256 major, uint256 minor, uint256 patch) = abi.decode(erc721ExchangeUpgraded.version(), (uint256, uint256, uint256));

		assertEq(major, _major);
		assertEq(minor, _minor);
		assertEq(patch, _patch + 1);
	}
}
