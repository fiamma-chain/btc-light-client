import * as dotenv from 'dotenv';
dotenv.config();

export interface Config {
    /** Bitcoin Mirror contract address */
    contractAddr: string;
    /** Ethereum RPC URL */
    rpcUrl: string;
    /** Bitcoin RPC URL */
    btcRpcUrl: string;
    /** Bitcoin RPC username */
    btcRpcUser: string;
    /** Bitcoin RPC password */
    btcRpcPass: string;
    /** Eth private key */
    privateKey: string;
    /** Bitcoin network, testnet or mainnet */
    bitcoinNetwork: "testnet" | "mainnet";
    /** When catching up, prove at most this many blocks per batch */
    maxBlocks: number;
    /** Polling interval in milliseconds */
    pollingInterval: number;
    /** Maximum transaction retry attempts for dropped transactions */
    maxRetries: number;
    /** Transaction timeout in milliseconds */
    txTimeout: number;
}

export function getConfig(): Config {
    return {
        contractAddr: requireEnv('BTCMIRROR_CONTRACT_ADDR'),
        rpcUrl: requireEnv('ETH_RPC_URL'),
        btcRpcUrl: requireEnv('BTC_RPC_URL'),
        btcRpcUser: requireEnv('BTC_RPC_USER'),
        btcRpcPass: requireEnv('BTC_RPC_PASS'),
        privateKey: requireEnv('ETH_SUBMITTER_PRIVATE_KEY'),
        bitcoinNetwork: requireEnv('BITCOIN_NETWORK') as "testnet" | "mainnet",
        maxBlocks: parseInt(requireEnv('MAX_BLOCKS_PER_BATCH')),
        pollingInterval: parseInt(process.env.POLLING_INTERVAL || '60000'), // Default 1 minute
        maxRetries: parseInt(process.env.MAX_TX_RETRIES || '3'), // Default 3 retries for failed transactions
        txTimeout: parseInt(process.env.TX_TIMEOUT || '120000'), // Default 2 minutes timeout (shorter for better polling rhythm)
    };
}

function requireEnv(name: string): string {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Environment variable ${name} is required`);
    }
    return value;
} 