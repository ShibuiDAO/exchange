import { ethers, upgrades } from 'hardhat';
import type { ERC721PutExchange } from '../typechain';

async function main() {
	const [deployer] = await ethers.getSigners();

	const ERC721PutExchangeContract = await ethers.getContractFactory('ERC721PutExchange');
	const ERC721Exchange = (await upgrades.upgradeProxy(
		'0xb5b866416bd4AA13e2026dCb08ee3688d1C9c117',
		ERC721PutExchangeContract
	)) as ERC721PutExchange;

	await ERC721Exchange.deployed();

	console.log([`"ERC721Exchange" deployed to ${ERC721Exchange.address}`, `Deployer address is ${deployer.address}`].join('\n'));
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
