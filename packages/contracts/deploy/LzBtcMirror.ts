import assert from 'assert'
import { type DeployFunction } from 'hardhat-deploy/types'
import { ChannelId, EndpointId } from '@layerzerolabs/lz-definitions'

const contractName = 'LzBtcMirror'
const verifierContractName = 'BtcTxVerifier'

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
        targetEid: EndpointId.ARBITRUM_V2_MAINNET,
        targetBtcMirror: '0x36A1a65947F48a34d1c93BB1eF88b3652D79f0a7',
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
    // Deploy BtcTxVerifier
    console.log(`\n📦 Deploying ${verifierContractName}...`)
    const verifierDeployment = await deploy(verifierContractName, {
        from: deployer,
        args: [address], // Use LzBtcMirror address as the mirror
        log: true,
        skipIfAlreadyDeployed: false,
    })

    // Verify BtcTxVerifier contract source code
    if (hre.network.name !== 'hardhat' && hre.network.name !== 'localhost') {
        console.log(`📋 Verifying ${verifierContractName} source code...`)
        try {
            await hre.run('verify:verify', {
                address: verifierDeployment.address,
                constructorArguments: [address],
            })
            console.log(`✅ ${verifierContractName} verified on block explorer!`)
        } catch (error: any) {
            console.log(`❌ Verification failed:`, error.message || error)
            console.log(`You can manually verify later with:`)
            console.log(`npx hardhat verify --network ${hre.network.name} ${verifierDeployment.address} ${address}`)
        }
    }

    console.log(`\n✅ Deployed ${verifierContractName}, network: ${hre.network.name}, address: ${verifierDeployment.address}`)
    console.log(`Configuration:`)
    console.log(`  - BtcMirror Address: ${address}`)
    console.log(`  - BtcTxVerifier Address: ${verifierDeployment.address}`)
}

deploy.tags = [contractName, verifierContractName]

export default deploy
