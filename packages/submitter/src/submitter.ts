import { Contract, ethers, Wallet } from "ethers";
import {
  getBlockCount,
  getBlockHash,
  getBlockHeader,
  BtcRpcClient,
  createBtcRpcClient,
} from "./bitcoin-rpc-client";
import { Config } from "./config";
import btcMirrorJson = require("../../contracts/out/BtcMirror.sol/BtcMirror.json");


export class BtcSubmitter {
  private readonly config: Config;
  private readonly provider: ethers.JsonRpcProvider;
  private readonly contract: Contract;
  private readonly rpc: BtcRpcClient;
  private isRunning = false;

  constructor(config: Config) {
    this.config = config;
    this.provider = new ethers.JsonRpcProvider(config.rpcUrl);
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
    const tx = await this.contract.submit(
      fromHeight,
      Buffer.from(headers.join(""), "hex"),
    );

    console.log(`Submitted tx ${tx.hash}, waiting for confirmation...`);
    await tx.wait();
    console.log('Transaction confirmed');
  }

  private async getCurrentMirrorHeight(): Promise<number> {
    const latestHeightRes = await this.contract.getLatestBlockHeight();
    const mirrorLatestHeight = Number(latestHeightRes);
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
    const maxReorg = 100;
    for (let height = mirrorLatestHeight; mirrorLatestHeight - maxReorg; height--) {
      const mirrorHash = (await this.contract.getBlockHash(height)).replace("0x", "");
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


function sleep(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time));
}
