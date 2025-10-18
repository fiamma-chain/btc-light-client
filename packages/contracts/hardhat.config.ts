import 'dotenv/config'

import 'hardhat-deploy'
import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
import '@nomicfoundation/hardhat-verify'


import '@layerzerolabs/toolbox-hardhat'
import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from 'hardhat/types'

import { EndpointId } from '@layerzerolabs/lz-definitions'

import './tasks/readBtcData'

// Set your preferred authentication method
//
// If you prefer using a mnemonic, set a MNEMONIC environment variable
// to a valid mnemonic
const MNEMONIC = process.env.MNEMONIC

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const PRIVATE_KEY = process.env.PRIVATE_KEY

// Alchemy API key for paid node access
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY

// Etherscan API key for contract verification (works for most EVM block explorers)
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
    ? { mnemonic: MNEMONIC }
    : PRIVATE_KEY
        ? [PRIVATE_KEY]
        : undefined

if (accounts == null) {
    console.warn(
        'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}

if (!ALCHEMY_API_KEY) {
    console.warn(
        'Could not find ALCHEMY_API_KEY environment variable. Network configurations will not work properly.'
    )
}

if (!ETHERSCAN_API_KEY) {
    console.warn(
        'Could not find ETHERSCAN_API_KEY environment variable. Contract verification will not work.'
    )
}

const config: HardhatUserConfig = {

    solidity: {
        version: '0.8.30',
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
            viaIR: true,
        },
    },
    paths: {
        artifacts: './out',
        sources: './src',
    },
    networks: {
        'ethereum': {
            eid: EndpointId.ETHEREUM_V2_MAINNET,
            url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
            accounts,
        },
        'bsc': {
            eid: EndpointId.BSC_V2_MAINNET,
            url: `https://bnb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
            accounts,
        },
        'polygon': {
            eid: EndpointId.POLYGON_V2_MAINNET,
            url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
            accounts,
        },
        'sei': {
            eid: EndpointId.SEI_V2_MAINNET,
            url: `https://sei-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
            accounts,
        },
        'base': {
            eid: EndpointId.BASE_V2_MAINNET,
            url: `https://base-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
            accounts,
        },
        'unichain': {
            eid: EndpointId.UNICHAIN_V2_MAINNET,
            url: `https://unichain-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
            accounts,
        },
        'hyperliquid': {
            eid: EndpointId.HYPERLIQUID_V2_MAINNET,
            url: `https://hyperliquid-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
            accounts,
        },
        'plume': {
            eid: EndpointId.PLUMEPHOENIX_V2_MAINNET,
            url: `https://rpc.plume.org`,
            accounts,
        },  
    },
    namedAccounts: {
        deployer: {
            default: 0, // Use the first account as deployer
        },
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY || '',
    },
    sourcify: {
        enabled: true
    }



}

export default config
