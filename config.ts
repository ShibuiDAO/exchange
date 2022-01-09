// eslint-disable-next-line @typescript-eslint/no-var-requires
require('dotenv').config();
import { z } from 'zod';

// // const privateKeySchema = z.string();
// // export const privateKey = privateKeySchema.parse(process.env.PRIVATE_KEY);

// // const etherscanApichema = z.string();
// // export const etherscanApi = etherscanApichema.parse(process.env.ETHERSCAN_API);

const coinMarketCapApiSchema = z.string();
export const coinMarketCapApi = coinMarketCapApiSchema.parse(process.env.COINMARKETCAP_API);

const alchemyRinkebyEthKeySchema = z.string();
export const alchemyRinkebyEthKey = alchemyRinkebyEthKeySchema.parse(process.env.ALCHEMY_RINKEBY_ETH_KEY);

const testnetPrivateKeySchema = z.string();
export const testnetPrivateKey = `${testnetPrivateKeySchema.parse(process.env.TESTNET_PRIVATE_KEY)}`;
