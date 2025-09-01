import { ethers } from 'ethers';
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
  private readonly contract: ethers.Contract;
  private readonly rpc: BtcRpcClient;
  private readonly wallet: ethers.Wallet;
  private isRunning = false;

  constructor(config: Config) {
    this.config = config;
    this.provider = new ethers.JsonRpcProvider(config.rpcUrl);
    this.wallet = new ethers.Wallet(config.privateKey, this.provider);
    this.contract = new ethers.Contract(
      config.contractAddr,
      btcMirrorJson.abi,
      this.wallet
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

      // Wait for next polling interval with ability to exit early
      await this.interruptibleWait(this.config.pollingInterval);
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

    // Prepare block headers buffer
    const blockHeaders = Buffer.from(headers.join(""), "hex");

    // Create hash of blockHeight and blockHeaders
    const abiCoder = ethers.AbiCoder.defaultAbiCoder();
    const hash = ethers.keccak256(
      abiCoder.encode(
        ['uint256', 'bytes'],
        [fromHeight, blockHeaders]
      )
    );

    // Sign the hash directly without the Ethereum message prefix
    const signature = await this.wallet.signingKey.sign(hash);

    // Submit transaction with timeout and retry mechanism
    await this.submitTransactionWithTimeout(fromHeight, blockHeaders, signature);
  }

  private async submitTransactionWithTimeout(
    fromHeight: number,
    blockHeaders: Buffer,
    signature: any
  ): Promise<void> {
    const maxRetries = this.config.maxRetries;
    
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        console.log(`Transaction attempt ${attempt}/${maxRetries}`);
        
        // Submit transaction
        const tx = await this.contract.submit_uncheck(
          fromHeight,
          blockHeaders,
          signature.v,
          signature.r,
          signature.s
        );

        console.log(`Submitted tx ${tx.hash}, waiting for confirmation...`);
        
        // Wait with timeout
        const timeoutPromise = new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Transaction timeout')), this.config.txTimeout)
        );

        try {
          await Promise.race([tx.wait(), timeoutPromise]);
          console.log('Transaction confirmed');
          return; // Success
        } catch (error) {
          if (error.message === 'Transaction timeout') {
            console.log(`Transaction timeout after ${this.config.txTimeout/1000}s. Checking if transaction was mined...`);
            
            // Check if transaction exists on chain and was successful
            const receipt = await this.provider.getTransactionReceipt(tx.hash);
            if (receipt) {
              if (receipt.status === 1) {
                console.log(`Transaction was successfully mined in block ${receipt.blockNumber}`);
                return; // Success
              } else {
                console.log(`Transaction was mined but failed (reverted) in block ${receipt.blockNumber}`);
                if (attempt === maxRetries) {
                  throw new Error('Transaction failed after all retries');
                }
              }
            } else {
              console.log('Transaction not found on chain, will retry...');
              if (attempt === maxRetries) {
                throw new Error('Transaction failed after all retries');
              }
            }
          } else {
            throw error; // Other errors should be re-thrown
          }
        }
        
      } catch (error) {
        console.log(`Attempt ${attempt} failed:`, error.message);
        
        if (attempt === maxRetries) {
          throw new Error(`All ${maxRetries} transaction attempts failed. Last error: ${error.message}`);
        }
        
        // Wait before retry
        const waitTime = 30000; // 30 seconds
        console.log(`Waiting ${waitTime/1000}s before retry...`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
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

  private async interruptibleWait(ms: number): Promise<void> {
    const checkInterval = 1000; // Check every 1 second
    const endTime = Date.now() + ms;
    
    while (Date.now() < endTime && this.isRunning) {
      const remainingTime = Math.min(checkInterval, endTime - Date.now());
      await new Promise(resolve => setTimeout(resolve, remainingTime));
    }
  }
}

function sleep(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time));
}
