import { defaultAbiCoder } from '@ethersproject/abi';
import { mkdirSync, writeFileSync } from 'fs';
import { ethers, upgrades } from 'hardhat';
import { join } from 'path';
import type { ERC721ExchangeUpgradeable, OrderBookUpgradeable, RoyaltyEngineV1, RoyaltyRegistry, WETH } from '../../typechain';

async function main() {
	const [deployer] = await ethers.getSigners();
	const shibuiMetaDirectory = join(__dirname, '..', '..', '.shibui');

	const WETHContract = await ethers.getContractFactory('WETH');
	const WETH = (await WETHContract.deploy()) as WETH;
	await WETH.deployed();

	const RoyaltyRegistryContract = await ethers.getContractFactory('RoyaltyRegistry');
	const RoyaltyRegistry = (await upgrades.deployProxy(RoyaltyRegistryContract, [], {
		initializer: '__RoyaltyRegistry_init',
		kind: 'transparent'
	})) as RoyaltyRegistry;
	await RoyaltyRegistry.deployed();

	const RoyaltyEngineV1Contract = await ethers.getContractFactory('RoyaltyEngineV1');
	const RoyaltyEngineV1 = (await upgrades.deployProxy(RoyaltyEngineV1Contract, [RoyaltyRegistry.address], {
		initializer: '__RoyaltyEngineV1_init',
		kind: 'transparent'
	})) as RoyaltyEngineV1;
	await RoyaltyEngineV1.deployed();

	const OrderBookUpgradeableContract = await ethers.getContractFactory('OrderBookUpgradeable');
	const OrderBookUpgradeable = (await upgrades.deployProxy(OrderBookUpgradeableContract, [], {
		initializer: '__OrderBook_init',
		kind: 'transparent'
	})) as OrderBookUpgradeable;
	await OrderBookUpgradeable.deployed();

	const ERC721ExchangeUpgradeableContract = await ethers.getContractFactory('ERC721ExchangeUpgradeable');
	const ERC721Exchange = (await upgrades.deployProxy(
		ERC721ExchangeUpgradeableContract,
		[29, RoyaltyEngineV1.address, OrderBookUpgradeable.address, WETH.address],
		{
			initializer: '__ERC721Exchange_init',
			kind: 'transparent'
		}
	)) as ERC721ExchangeUpgradeable;
	await ERC721Exchange.deployed();

	await OrderBookUpgradeable.addOrderKeeper(ERC721Exchange.address);

	const ERC721ExchangeUpgrades = (await upgrades.deployProxy(
		ERC721ExchangeUpgradeableContract,
		[29, RoyaltyEngineV1.address, OrderBookUpgradeable.address, WETH.address],
		{
			initializer: '__ERC721Exchange_init',
			kind: 'transparent'
		}
	)) as ERC721ExchangeUpgradeable;
	await ERC721ExchangeUpgrades.deployed();

	await OrderBookUpgradeable.addOrderKeeper(ERC721ExchangeUpgrades.address);

	const ERC721ExchangeUpgradedContract = await ethers.getContractFactory('ERC721ExchangeUpgradeableUpgraded');
	const ERC721ExchangeUpgradesUpgraded = (await upgrades.upgradeProxy(
		ERC721ExchangeUpgrades.address,
		ERC721ExchangeUpgradedContract
	)) as ERC721ExchangeUpgradeable;

	console.log(
		[
			`Joint testnet contracts: ` /**/,
			` - "WETH" deployed to ${WETH.address}`,
			` - "RoyaltyRegistry" deployed to ${RoyaltyRegistry.address}`,
			` - "RoyaltyEngineV1" deployed to ${RoyaltyEngineV1.address}`,
			` - "OrderBookUpgradeable" deployed to ${OrderBookUpgradeable.address}`,
			` - "ERC721Exchange" (base) deployed to ${ERC721Exchange.address}`,
			` - "ERC721Exchange" (upgraded) deployed to ${ERC721ExchangeUpgradesUpgraded.address}`,
			` - Deployer address is ${deployer.address}`
		].join('\n')
	);

	const encodedData = defaultAbiCoder.encode(
		['address', 'address', 'address', 'address', 'address'],
		[
			RoyaltyRegistry.address,
			RoyaltyEngineV1.address,
			OrderBookUpgradeable.address,
			ERC721Exchange.address,
			ERC721ExchangeUpgradesUpgraded.address
		]
	);

	mkdirSync(shibuiMetaDirectory, { recursive: true });
	writeFileSync(join(shibuiMetaDirectory, 'deployments'), encodedData, {
		flag: 'w'
	});
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
