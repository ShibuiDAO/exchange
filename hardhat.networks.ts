import type { NetworksUserConfig } from 'hardhat/types';
import { alchemyRinkebyEthKey, testnetPrivateKey } from './config.hardhat';

export const networks: NetworksUserConfig = {
	hardhat: {},
	local: {
		chainId: 99,
		url: 'http://127.0.0.1:8545',
		allowUnlimitedContractSize: true
	},
	localh: {
		chainId: 31337,
		url: 'http://127.0.0.1:8545',
		allowUnlimitedContractSize: true
	},
	rinkey: {
		url: `https://eth-rinkeby.alchemyapi.io/v2/${alchemyRinkebyEthKey}`,
		accounts: [testnetPrivateKey]
	},
	bobaRinkeby: {
		url: 'https://rinkeby.boba.network/',
		accounts: [testnetPrivateKey]
	}
};
