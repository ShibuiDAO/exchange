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
import type { HardhatUserConfig } from 'hardhat/config';
import 'solidity-coverage';
import { alchemyRinkebyEthKey, coinMarketCapApi, testnetPrivateKey } from './config';

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
		hardhat: {},
		rinkey: {
			url: `https://eth-rinkeby.alchemyapi.io/v2/${alchemyRinkebyEthKey}`,
			accounts: [testnetPrivateKey]
		},
		bobaRinkeby: {
			url: 'https://rinkeby.boba.network/',
			accounts: [testnetPrivateKey]
		}
	},
	// etherscan: {
	// 	apiKey: etherscanApi
	// },
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
	},
	dodoc: {
		runOnCompile: true,
		testMode: true
	}
};

export default config;
