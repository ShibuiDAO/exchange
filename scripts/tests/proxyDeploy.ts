import { defaultAbiCoder } from '@ethersproject/abi';
import { mkdirSync, writeFileSync } from 'fs';
import { ethers, upgrades } from 'hardhat';
import { join } from 'path';
import type { ERC721PutExchange, WETH } from '../../typechain';

async function main() {
	const [deployer] = await ethers.getSigners();
	const shibuiMetaDirectory = join(__dirname, '..', '..', '.shibui');

	const WETHContract = await ethers.getContractFactory('WETH');
	const WETH = (await WETHContract.deploy()) as WETH;

	await WETH.deployed();

	const ERC721PutExchangeContract = await ethers.getContractFactory('ERC721PutExchange');
	const ERC721Exchange = (await upgrades.deployProxy(ERC721PutExchangeContract, [300, 29, WETH.address], {
		initializer: '__ERC721Exchange_init',
		kind: 'transparent'
	})) as ERC721PutExchange;

	await ERC721Exchange.deployed();

	const ERC721ExchangeUpgrades = (await upgrades.deployProxy(ERC721PutExchangeContract, [300, 29, WETH.address], {
		initializer: '__ERC721Exchange_init',
		kind: 'transparent'
	})) as ERC721PutExchange;

	await ERC721ExchangeUpgrades.deployed();

	const ERC721ExchangeUpgradedContract = await ethers.getContractFactory('ERC721PutExchangeUpgraded');
	const ERC721ExchangeUpgradesUpgraded = (await upgrades.upgradeProxy(
		ERC721ExchangeUpgrades.address,
		ERC721ExchangeUpgradedContract
	)) as ERC721PutExchange;

	console.log(
		[
			`Joint testnet contracts: ` /**/,
			` - "WETH" deployed to ${WETH.address}`,
			` - "ERC721Exchange" (base) deployed to ${ERC721Exchange.address}`,
			` - "ERC721Exchange" (upgraded) deployed to ${ERC721ExchangeUpgradesUpgraded.address}`,
			` - Deployer address is ${deployer.address}`
		].join('\n')
	);

	const encodedData = defaultAbiCoder.encode(['address', 'address'], [ERC721Exchange.address, ERC721ExchangeUpgradesUpgraded.address]);

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
