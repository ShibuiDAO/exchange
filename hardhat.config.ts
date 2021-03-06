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
import { coinMarketCapApi } from './config.hardhat';
import { networks } from './networks.hardhat';

task('accounts', 'Prints the list of accounts', async (_, hre) => {
	const accounts = await hre.ethers.getSigners();

	for (const account of accounts) {
		console.log(account.address);
	}
});

const config: HardhatUserConfig = {
	paths: {
		sources: './src/contracts',
		tests: './test'
	},
	solidity: {
		version: '0.8.9',
		settings: {
			optimizer: {
				enabled: true,
				runs: 1000000
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
		only: ['ERC721ExchangeUpgradeable.sol', 'OrderBookUpgradeable.sol']
	},
	gasReporter: {
		excludeContracts: ['contracts/mocks/', 'src/contracts/mocks/', 'test/', 'src/test/'],
		showTimeSpent: true,
		currency: 'USD',
		gasPrice: 1,
		coinmarketcap: coinMarketCapApi
	}
};

export default config;
