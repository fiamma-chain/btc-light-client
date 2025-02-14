import { BigNumber, Contract, ethers, Wallet } from "ethers";
import {
  getBlockCount,
  getBlockHash,
  getBlockHeader,
  BtcRpcClient,
  createBtcRpcClient,
} from "./bitcoin-rpc-client";
import { Config } from "./config";
import btcMirrorJson = require("../../contracts/out/BtcMirror.sol/BtcMirror.json");

// We do NOT import '@eth-optimism/contracts'. that package has terrible
// dependency hygiene. you end up trying to node-gyp compile libusb, wtf.
// all we need is a plain ABI json and a contract address:
import optGPOAbi = require("../abi/OptimismGasPriceOracle.json");
const optGPOAddr = "0x420000000000000000000000000000000000000F";

export class BtcSubmitter {
  private readonly config: Config;
  private readonly provider: ethers.providers.JsonRpcProvider;
  private readonly contract: Contract;
  private readonly rpc: BtcRpcClient;
  private isRunning = false;

  constructor(config: Config) {
    this.config = config;
    this.provider = new ethers.providers.JsonRpcProvider(config.rpcUrl);
    this.contract = new Contract(
      config.contractAddr,
      btcMirrorJson.abi,
      new Wallet(config.privateKey, this.provider)
    );
    this.rpc = createBtcRpcClient(config);
  }

  public async start() {
    if (this.isRunning) {
      console.log('Submitter is already running');
      return;
    }

    this.isRunning = true;
    console.log('Starting BTC submitter...');

    while (this.isRunning) {
      try {
        await this.submitNewBlocks();
      } catch (error) {
        console.error('Error in submit loop:', error);
      }

      // Wait for next polling interval
      await new Promise(resolve => setTimeout(resolve, this.config.pollingInterval));
    }
  }

  public stop() {
    this.isRunning = false;
    console.log('Stopping BTC submitter...');
  }

  private async submitNewBlocks() {
    // Get current heights
    const mirrorHeight = await this.getCurrentMirrorHeight();
    const btcHeight = await this.getCurrentBtcHeight();

    if (btcHeight <= mirrorHeight) {
      console.log('No new blocks to submit');
      return;
    }

    const targetHeight = Math.min(
      btcHeight,
      mirrorHeight + this.config.maxBlocks
    );

    // Get blocks to submit
    const { fromHeight, hashes } = await this.getBlockHashesToSubmit(
      mirrorHeight,
      targetHeight
    );

    // Get block headers
    const headers = await this.loadBlockHeaders(hashes);
    console.log(`Loaded BTC blocks ${fromHeight}-${targetHeight}`);

    // Submit transaction
    const gasLimit = 100000 + 30000 * headers.length;
    const tx = await this.contract.functions.submit(
      fromHeight,
      Buffer.from(headers.join(""), "hex"),
      { gasLimit }
    );

    console.log(`Submitted tx ${tx.hash}, waiting for confirmation...`);
    await tx.wait();
    console.log('Transaction confirmed');
  }

  private async getCurrentMirrorHeight(): Promise<number> {
    const latestHeightRes = await this.contract.functions["getLatestBlockHeight"]();
    const mirrorLatestHeight = (latestHeightRes[0] as BigNumber).toNumber();
    console.log("got BtcMirror latest block height: " + mirrorLatestHeight);
    return mirrorLatestHeight;
  }

  private async getCurrentBtcHeight(): Promise<number> {
    const btcTipHeight = await getBlockCount(this.rpc);
    console.log("got BTC latest block height: " + btcTipHeight);
    return btcTipHeight;
  }

  private async getBlockHashesToSubmit(
    mirrorHeight: number,
    targetHeight: number
  ): Promise<{
    fromHeight: number;
    hashes: string[];
  }> {
    console.log("finding last common Bitcoin block");
    const hashes = [] as string[];
    const lch = await this.getLastCommonHeight(mirrorHeight, hashes);
    console.log(`last common height ${lch}`);
    const fromHeight = lch + 1;
    const promises = [] as Promise<string>[];
    for (let height = mirrorHeight + 1; height <= targetHeight; height++) {
      promises.push(getBlockHash(this.rpc, height));
    }
    hashes.push(...(await Promise.all(promises)));

    return { fromHeight, hashes };
  }

  private async getLastCommonHeight(
    mirrorLatestHeight: number,
    hashes: string[]
  ) {
    const maxReorg = 20;
    for (let height = mirrorLatestHeight; mirrorLatestHeight - maxReorg; height--) {
      const mirrorResult = await this.contract.functions["getBlockHash"](height);
      const mirrorHash = (mirrorResult[0] as string).replace("0x", "");
      const btcHash = await getBlockHash(this.rpc, height);
      console.log(`height ${height} btc ${btcHash} btcmirror ${mirrorHash}`);
      if (btcHash === mirrorHash) {
        console.log(`found common hash ${height}: ${btcHash}`);
        return height;
      } else if (height === mirrorLatestHeight - maxReorg) {
        throw new Error(
          `no common hash found within ${maxReorg} blocks. catastrophic reorg?`
        );
      }
      hashes.unshift(btcHash);
    }
  }

  private async loadBlockHeaders(
    hashes: string[]
  ): Promise<string[]> {
    const promises = hashes.map((hash: string) => getBlockHeader(this.rpc, hash));
    return await Promise.all(promises);
  }
}

async function getOptimismBasefee(ethProvider: ethers.providers.Provider) {
  const gasPriceOracle = new Contract(optGPOAddr, optGPOAbi, ethProvider);
  const l1BaseFeeRes = await gasPriceOracle.functions["l1BaseFee"]();
  const l1BaseFeeGwei = Math.round(l1BaseFeeRes[0] / 1e9);
  console.log(`optimism L1 basefee: ${l1BaseFeeGwei} gwei`);
  return l1BaseFeeGwei;
}

function sleep(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time));
}
