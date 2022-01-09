import { ethers, upgrades } from 'hardhat';
import { WETHAddress } from '../constants';
import type { ERC721ExchangeUpgradeable } from '../typechain';

async function main() {
	const [deployer] = await ethers.getSigners();

	const ERC721ExchangeUpgradeableContract = await ethers.getContractFactory('ERC721ExchangeUpgradeable');
	const ERC721Exchange = (await upgrades.deployProxy(ERC721ExchangeUpgradeableContract, [300, 29, WETHAddress], {
		initializer: '__ERC721Exchange_init',
		kind: 'transparent'
	})) as ERC721ExchangeUpgradeable;

	await ERC721Exchange.deployed();

	console.log([`"ERC721Exchange" deployed to ${ERC721Exchange.address}`, `Deployer address is ${deployer.address}`].join('\n'));
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
