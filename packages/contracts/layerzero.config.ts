import { ChannelId, EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import { type OAppReadOmniGraphHardhat, type OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'



const baseContract: OmniPointHardhat = {
    eid: EndpointId.BASESEP_V2_TESTNET,
    contractName: 'LzBtcMirror',
}

const config: OAppReadOmniGraphHardhat = {
    contracts: [

        {
            contract: baseContract,
            config: {
                readChannelConfigs: [
                    {
                        channelId: ChannelId.READ_CHANNEL_1,
                        active: true,
                        readLibrary: '0x29270F0CFC54432181C853Cd25E2Fb60A68E03f2',
                        ulnConfig: {
                            requiredDVNs: ['0xbf6ff58f60606edb2f190769b951d825bcb214e2'],
                            executor: '0x8A3D588D9f6AC041476b094f97FF94ec30169d3D',
                        },
                        enforcedOptions: [
                            {
                                msgType: 1,
                                optionType: ExecutorOptionType.LZ_READ,
                                gas: 80000,
                                size: 96, // uint256 (32 bytes) + uint256 (32 bytes) + bytes32 (32 bytes) = 96 bytes
                                value: 0,
                            },
                        ],
                    },
                ],
            },
        },
    ],
    connections: [],
}

export default config
