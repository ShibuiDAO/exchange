import { defaultAbiCoder } from '@ethersproject/abi';
import { mkdirSync, writeFileSync } from 'fs';
import { ethers, upgrades } from 'hardhat';
import { join } from 'path';
import type { ERC721ExchangeUpgradeable, WETH } from '../../typechain';

async function main() {
	const [deployer] = await ethers.getSigners();
	const shibuiMetaDirectory = join(__dirname, '..', '..', '.shibui');

	const WETHContract = await ethers.getContractFactory('WETH');
	const WETH = (await WETHContract.deploy()) as WETH;

	await WETH.deployed();

	const ERC721ExchangeUpgradeableContract = await ethers.getContractFactory('ERC721ExchangeUpgradeable');
	const ERC721Exchange = (await upgrades.deployProxy(ERC721ExchangeUpgradeableContract, [300, 29, WETH.address], {
		initializer: '__ERC721Exchange_init',
		kind: 'transparent'
	})) as ERC721ExchangeUpgradeable;

	await ERC721Exchange.deployed();

	console.log(
		[
			`Joint testnet contracts: ` /**/,
			` - "WETH" deployed to ${WETH.address}`,
			` - "ERC721Exchange" deployed to ${ERC721Exchange.address}`,
			` - Deployer address is ${deployer.address}`
		].join('\n')
	);

	mkdirSync(shibuiMetaDirectory, { recursive: true });
	writeFileSync(join(shibuiMetaDirectory, 'deployments'), defaultAbiCoder.encode(['address'], [ERC721Exchange.address]), {
		flag: 'w'
	});
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
