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

    // Hub configuration - All LzBtcMirror contracts point to Arbitrum
    const HUB_CONFIG = {
        targetEid: EndpointId.ARBSEP_V2_TESTNET,
        targetBtcMirror: '0x19BEE54b8EDA9c938AC1Ef164751e937596a024b',
    }

    if (HUB_CONFIG.targetBtcMirror === '0x0000000000000000000000000000000000000000') {
        console.warn(`⚠️  WARNING: targetBtcMirror address not set for Arbitrum Hub`)
        console.warn('Please update HUB_CONFIG.targetBtcMirror in deploy/LzBtcMirror.ts before deployment')
    }

    const { address, newlyDeployed } = await deploy(contractName, {
        from: deployer,
        args: [
            endpointV2Deployment.address, // LayerZero EndpointV2 address
            deployer, // owner/delegate
            ChannelId.READ_CHANNEL_1, // LayerZero read channel ID
            HUB_CONFIG.targetEid, // Target chain endpoint ID
            HUB_CONFIG.targetBtcMirror, // BtcMirror contract address on target chain
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    })

    // Verify contract source code if verification is requested and we're not on a local network
    if (hre.network.name !== 'hardhat' && hre.network.name !== 'localhost') {
        console.log(`📋 Verifying contract source code...`)
        try {
            await hre.run('verify:verify', {
                address: address,
                constructorArguments: [
                    endpointV2Deployment.address,
                    deployer,
                    ChannelId.READ_CHANNEL_1,
                    HUB_CONFIG.targetEid,
                    HUB_CONFIG.targetBtcMirror,
                ],
            })
            console.log(`✅ Contract verified on block explorer!`)
        } catch (error: any) {
            console.log(`❌ Verification failed:`, error.message || error)
            console.log(`You can manually verify later with:`)
            console.log(`npx hardhat verify --network ${hre.network.name} ${address} ${endpointV2Deployment.address} ${deployer} ${ChannelId.READ_CHANNEL_1} ${HUB_CONFIG.targetEid} ${HUB_CONFIG.targetBtcMirror}`)
        }
    }

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)
    console.log(`Configuration:`)
    console.log(`  - LayerZero Endpoint: ${endpointV2Deployment.address}`)
    console.log(`  - Target EID: ${HUB_CONFIG.targetEid}`)
    console.log(`  - Target BtcMirror: ${HUB_CONFIG.targetBtcMirror}`)
}

deploy.tags = [contractName]

export default deploy
