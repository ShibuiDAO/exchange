import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-solhint';
import '@nomiclabs/hardhat-waffle';
import '@openzeppelin/hardhat-upgrades';
import '@primitivefi/hardhat-dodoc';
import '@typechain/hardhat';
import 'hardhat-abi-exporter';
import 'hardhat-gas-reporter';
import 'hardhat-tracer';
import { HardhatUserConfig, task } from 'hardhat/config';
import 'solidity-coverage';
import { coinMarketCapApi } from './config';
import { networks } from './hardhat.networks';

task('accounts', 'Prints the list of accounts', async (_, hre) => {
	const accounts = await hre.ethers.getSigners();

	for (const account of accounts) {
		console.log(account.address);
	}
});

const config: HardhatUserConfig = {
	solidity: {
		version: '0.8.6',
		settings: {
			optimizer: {
				enabled: true
			}
		}
	},
	defaultNetwork: 'localh',
	networks,
	abiExporter: {
		path: './abis',
		runOnCompile: true,
		clear: true,
		flat: true,
		only: ['ERC721ExchangeUpgradeable.sol']
	},
	gasReporter: {
		excludeContracts: ['mocks/', 'contracts/mocks/'],
		showTimeSpent: true,
		currency: 'EUR',
		gasPrice: 10,
		coinmarketcap: coinMarketCapApi
	}
};

export default config;
