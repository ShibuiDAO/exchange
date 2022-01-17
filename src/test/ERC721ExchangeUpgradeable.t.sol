pragma solidity ^0.8.2;

import 'ds-test/test.sol';

import {IHvm} from './IHvm.sol';
import {IExchange} from '../contracts/interfaces/IExchange.sol';

contract ERC721ExchangeUpgradeableTest is DSTest {
	IExchange erc721Exchange;

	IHvm hevm = IHvm(address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));

	function setUp() public {
		string[] memory deploymentAddressCommand = new string[](2);
		deploymentAddressCommand[0] = 'cat';
		deploymentAddressCommand[1] = '.shibui/deployments';

		bytes memory deploymentAddresses = hevm.ffi(deploymentAddressCommand);
		address _erc721exchange = abi.decode(deploymentAddresses, (address));

		erc721Exchange = IExchange(_erc721exchange);
	}

	function test_deployment_version() public {
		assertEq('v1.0.3', erc721Exchange.version());
	}
}
