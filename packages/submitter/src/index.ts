/**
 * Welcome to Cloudflare Workers! This is your first scheduled worker.
 *
 * - Run `wrangler dev --local` in your terminal to start a development server
 * - Run `curl "http://localhost:8787/cdn-cgi/mf/scheduled"` to trigger the scheduled event
 * - Go back to the console to see what your worker has logged
 * - Update the Cron trigger in wrangler.toml (see https://developers.cloudflare.com/workers/wrangler/configuration/#triggers)
 * - Run `wrangler publish --name my-worker` to publish your worker
 *
 * Learn more at https://developers.cloudflare.com/workers/runtime-apis/scheduled-event/
 */

import { getConfig } from './config';
import { BtcSubmitter } from './submitter';

async function main() {
  const config = getConfig();
  const submitter = new BtcSubmitter(config);

  // Handle shutdown gracefully
  process.on('SIGINT', () => {
    console.log('Received SIGINT, shutting down...');
    submitter.stop();
    
    // Force exit after 3 seconds if graceful shutdown fails
    setTimeout(() => {
      console.log('Force exit after timeout');
      process.exit(1);
    }, 3000);
  });

  process.on('SIGTERM', () => {
    console.log('Received SIGTERM, shutting down...');
    submitter.stop();
    
    // Force exit after 3 seconds if graceful shutdown fails
    setTimeout(() => {
      console.log('Force exit after timeout');
      process.exit(1);
    }, 3000);
  });

  await submitter.start();
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
