import assert from 'assert'
import { type DeployFunction } from 'hardhat-deploy/types'
import { ChannelId, EndpointId } from '@layerzerolabs/lz-definitions'

const contractName = 'LzBtcMirror'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)

    // Get LayerZero EndpointV2 deployment
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')

    // Configuration for different networks
    const networkConfigs = {
        'ethereum': {
            targetEid: EndpointId.ARBITRUM_V2_MAINNET,
            targetBtcMirror: '0x0000000000000000000000000000000000000000', // TODO: Set actual target BtcMirror address
        },
        'polygon': {
            targetEid: EndpointId.ARBITRUM_V2_MAINNET,
            targetBtcMirror: '0x0000000000000000000000000000000000000000', // TODO: Set actual target BtcMirror address
        },
        'sepolia': {
            targetEid: EndpointId.ARBSEP_V2_TESTNET,
            targetBtcMirror: '0x0000000000000000000000000000000000000000', // TODO: Set actual target BtcMirror address
        },
        'base': {
            targetEid: EndpointId.ARBITRUM_V2_MAINNET,
            targetBtcMirror: '0x0000000000000000000000000000000000000000', // TODO: Set actual target BtcMirror address
        }
    }

    const config = networkConfigs[hre.network.name as keyof typeof networkConfigs]

    if (!config) {
        throw new Error(`Network ${hre.network.name} not supported for LzBtcMirror deployment`)
    }

    if (config.targetBtcMirror === '0x0000000000000000000000000000000000000000') {
        console.warn(`⚠️  WARNING: targetBtcMirror address not set for ${hre.network.name}`)
        console.warn('Please update the address in deploy/LzBtcMirror.ts before deployment')
    }

    const { address } = await deploy(contractName, {
        from: deployer,
        args: [
            endpointV2Deployment.address, // LayerZero EndpointV2 address
            deployer, // owner/delegate
            ChannelId.READ_CHANNEL_1, // LayerZero read channel ID
            config.targetEid, // Target chain endpoint ID
            config.targetBtcMirror, // BtcMirror contract address on target chain
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    })

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)
    console.log(`Configuration:`)
    console.log(`  - LayerZero Endpoint: ${endpointV2Deployment.address}`)
    console.log(`  - Target EID: ${config.targetEid}`)
    console.log(`  - Target BtcMirror: ${config.targetBtcMirror}`)
    console.log(`  - Read Channel: ${ChannelId.READ_CHANNEL_1}`)
}

deploy.tags = [contractName]

export default deploy
