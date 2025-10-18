import { ChannelId, EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import { type OAppReadOmniGraphHardhat, type OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

// Common contract name for all networks
const CONTRACT_NAME = 'LzBtcMirror'

// Network-specific configurations (only specify what's different for each network)
interface NetworkConfig {
    eid: EndpointId
    readLibrary: string
    requiredDVNs: string[]
    executor: string
}

// Helper function to create contract configuration
function createContractConfig(networkConfig: NetworkConfig) {
    return {
        contract: {
            eid: networkConfig.eid,
            contractName: CONTRACT_NAME,
        } as OmniPointHardhat,
        config: {
            readChannelConfigs: [
                {
                    channelId: ChannelId.READ_CHANNEL_1,
                    active: true,
                    readLibrary: networkConfig.readLibrary,
                    ulnConfig: {
                        requiredDVNs: networkConfig.requiredDVNs,
                        executor: networkConfig.executor,
                    },
                    enforcedOptions: [
                        {
                            msgType: 1,
                            optionType: ExecutorOptionType.LZ_READ,
                            gas: 80000,
                            size: 96, // uint256 (32 bytes) + uint256 (32 bytes) + bytes32 (32 bytes) = 96 bytes
                            value: 0,
                        },
                    ] as any,
                },
            ],
        },
    }
}

// Network configurations - add or modify networks here
const NETWORK_CONFIGS: NetworkConfig[] = [
    // Base
    {
        eid: EndpointId.BASE_V2_MAINNET,
        readLibrary: '0x1273141a3f7923AA2d9edDfA402440cE075ed8Ff',
        requiredDVNs: ['0xb1473ac9f58fb27597a21710da9d1071841e8163'],
        executor: '0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4',
    },
    
    // Polygon
    {
        eid: EndpointId.POLYGON_V2_MAINNET,
        readLibrary: '0xc214d690031d3f873365f94d381d6d50c35aa7fa',
        requiredDVNs: ['0xa70c51c38d5a9990f3113a403d74eba01fce4ccb'],
        executor: '0xCd3F213AD101472e1713C72B1697E727C803885b',
    },
    
    // BSC
    {
        eid: EndpointId.BSC_V2_MAINNET,
        readLibrary: '0x37375049CDc522Bd6bAeEbf527A42D54688d784c',
        requiredDVNs: ['0x509889389cfb7a89850017425810116a44676f58'],
        executor: '0x3ebD570ed38B1b3b4BC886999fcF507e9D584859',
    },
    
    // Ethereum
    {
        eid: EndpointId.ETHEREUM_V2_MAINNET,
        readLibrary: '0x74F55Bc2a79A27A0bF1D1A35dB5d0Fc36b9FDB9D',
        requiredDVNs: ['0xdb979d0a36af0525afa60fc265b1525505c55d79'],
        executor: '0x173272739Bd7Aa6e4e214714048a9fE699453059',
    },
    
    // Sei
    {
        eid: EndpointId.SEI_V2_MAINNET,
        readLibrary: '0x6A6C548058094e6dFaF95Bb0b5d04e1dd8ec0870',
        requiredDVNs: ['0xf6eddf89a273b5cbfbc54cee618762983823c3f4'],
        executor: '0xc097ab8CD7b053326DFe9fB3E3a31a0CCe3B526f',
    },
    
    // Unichain
    {
        eid: EndpointId.UNICHAIN_V2_MAINNET,
        readLibrary: '0x178F93794328C04988bcD52a1B820eC105b17f2f',
        requiredDVNs: ['0xb85775a6868c1a729447951fd59f9f7f095cd0b1'],
        executor: '0x4208D6E27538189bB48E603D6123A94b8Abe0A0b',
    },
    
    // Hyperliquid
    {
        eid: EndpointId.HYPERLIQUID_V2_MAINNET,
        readLibrary: '0xefF88eC9555b33A39081231131f0ed001FA9F96C',
        requiredDVNs: ['0x7ffd4989882a006ac51f324b4889b3087d71b716'],
        executor: '0x41Bdb4aa4A63a5b2Efc531858d3118392B1A1C3d',
    },
    
    // Plume    
    {
        eid: EndpointId.PLUMEPHOENIX_V2_MAINNET,
        readLibrary: '0x7155c16E82919Ee77927d3A8cE180930f04d4428',
        requiredDVNs: ['0xaf75bfd402f3d4ee84978179a6c87d16c4bd1724'],
        executor: '0x41Bdb4aa4A63a5b2Efc531858d3118392B1A1C3d',
    },


]

const config: OAppReadOmniGraphHardhat = {
    contracts: NETWORK_CONFIGS.map(createContractConfig),
    connections: [],
}

export default config
