import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-solhint';
import '@nomiclabs/hardhat-waffle';
import '@openzeppelin/hardhat-upgrades';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'hardhat-tracer';
import type { HardhatUserConfig } from 'hardhat/config';
import 'solidity-coverage';
import { coinMarketCapApi } from './config';

const config: HardhatUserConfig = {
	solidity: {
		version: '0.8.2',
		settings: {
			optimizer: {
				enabled: true
			}
		}
	},
	defaultNetwork: 'hardhat',
	networks: {
		hardhat: {
			// forking: {
			// 	url: 'https://bsc-dataseed.binance.org',
			// 	blockNumber: 11224630
			// }
		}
	},
	// etherscan: {
	// 	apiKey: etherscanApi
	// },
	gasReporter: {
		excludeContracts: ['mocks/'],
		showTimeSpent: true,
		currency: 'EUR',
		gasPrice: 10,
		coinmarketcap: coinMarketCapApi
	}
};

export default config;
