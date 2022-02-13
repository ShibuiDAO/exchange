import assert from 'assert';
import { ethers, upgrades } from 'hardhat';
import { WETHAddress } from '../constants.hardhat';
import type { ERC721ExchangeUpgradeable, OrderBookUpgradeable } from '../typechain';

const ROYALTY_ENGINE = process.env.ROYALTY_ENGINE || '0x523DC4588ce47e17854B26296458946b9052b9ED';
const SYSTEM_FEE = 29; // 2,9%

async function main() {
	assert.notEqual(ROYALTY_ENGINE, undefined);

	const [deployer] = await ethers.getSigners();

	const OrderBookUpgradeableContract = await ethers.getContractFactory('OrderBookUpgradeable');
	const OrderBookUpgradeable = (await upgrades.deployProxy(OrderBookUpgradeableContract, [], {
		initializer: '__OrderBook_init',
		kind: 'transparent'
	})) as OrderBookUpgradeable;
	await OrderBookUpgradeable.deployed();

	const ERC721ExchangeUpgradeableContract = await ethers.getContractFactory('ERC721ExchangeUpgradeable');
	const ERC721ExchangeUpgradeable = (await upgrades.deployProxy(
		ERC721ExchangeUpgradeableContract,
		[SYSTEM_FEE, ROYALTY_ENGINE, OrderBookUpgradeable.address, WETHAddress],
		{
			initializer: '__ERC721Exchange_init',
			kind: 'transparent'
		}
	)) as ERC721ExchangeUpgradeable;
	await ERC721ExchangeUpgradeable.deployed();

	await ERC721ExchangeUpgradeable.setSystemFeeWallet(deployer.address);
	await OrderBookUpgradeable.addOrderKeeper(ERC721ExchangeUpgradeable.address);

	console.log(
		[
			` - "OrderBookUpgradeable" deployed to ${OrderBookUpgradeable.address}`,
			` - "ERC721ExchangeUpgradeable" deployed to ${ERC721ExchangeUpgradeable.address}`,
			`Deployer address is ${deployer.address}`
		].join('\n')
	);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
