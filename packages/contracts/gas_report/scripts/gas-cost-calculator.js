#!/usr/bin/env node

/**
 * Gas Cost Calculator - Markdown Report Generator
 * Generate Markdown format Gas cost analysis report based on Forge test reports
 */

const fs = require('fs');
const path = require('path');

// Configuration parameters
const CONFIG = {
    // Gas price (gwei) - can be adjusted based on network conditions
    GAS_PRICE_GWEI: 5,

    // ETH price (USD)
    ETH_PRICE_USD: 2500,

    // 1 gwei = 10^9 wei, 1 ETH = 10^18 wei
    GWEI_TO_ETH: 1e-9,
    WEI_TO_ETH: 1e-18
};

/**
 * Load gas report data
 */
function loadGasReportData() {
    const dataPath = path.join(__dirname, '..', 'gas-report-data.json');

    if (!fs.existsSync(dataPath)) {
        console.error('❌ Gas report data file not found. Please run the analysis first.');
        console.error(`   Expected location: ${dataPath}`);
        process.exit(1);
    }

    try {
        const jsonData = fs.readFileSync(dataPath, 'utf8');
        const gasData = JSON.parse(jsonData);
        return gasData;
    } catch (error) {
        console.error('❌ Failed to load gas report data:', error.message);
        process.exit(1);
    }
}

/**
 * Convert gas to ETH
 */
function gasToEth(gasAmount, gasPriceGwei = CONFIG.GAS_PRICE_GWEI) {
    return gasAmount * gasPriceGwei * CONFIG.GWEI_TO_ETH;
}

/**
 * Convert ETH to USD
 */
function ethToUsd(ethAmount, ethPriceUsd = CONFIG.ETH_PRICE_USD) {
    return ethAmount * ethPriceUsd;
}

/**
 * Format number display
 */
function formatNumber(num, decimals = 6) {
    return parseFloat(num.toFixed(decimals));
}

/**
 * Format USD display
 */
function formatUsd(amount) {
    return `$${amount.toFixed(4)}`;
}

/**
 * Generate Markdown format report
 */
function generateMarkdownReport(gasReportData, customConfig = {}) {
    const config = { ...CONFIG, ...customConfig };
    const timestamp = new Date().toISOString();
    const date = new Date().toLocaleDateString();

    let md = `# 📊 Gas Cost Analysis Report

> **Generated on:** ${date}  
> **Configuration:** Gas Price = ${config.GAS_PRICE_GWEI} gwei, ETH Price = $${config.ETH_PRICE_USD}  
> **Timestamp:** ${timestamp}

---

`;

    // Generate detailed information for each contract
    gasReportData.contracts.forEach((contract, index) => {
        const deploymentEth = gasToEth(contract.deployment.cost, config.GAS_PRICE_GWEI);
        const deploymentUsd = ethToUsd(deploymentEth, config.ETH_PRICE_USD);

        md += `## ${index + 1}. ${contract.name} Contract

### 📦 Deployment Cost

| Metric | Value |
|--------|-------|
| **Gas Used** | ${contract.deployment.cost.toLocaleString()} |
| **ETH Cost** | ${formatNumber(deploymentEth)} ETH |
| **USD Cost** | ${formatUsd(deploymentUsd)} |
| **Contract Size** | ${contract.deployment.size} bytes |

### ⚡ Function Call Costs (Per Transaction)

| Function Name | Avg Gas | ETH Cost | USD Cost |
|---------------|---------|----------|----------|
`;

        contract.functions.forEach(func => {
            const avgEth = gasToEth(func.avg, config.GAS_PRICE_GWEI);
            const avgUsd = ethToUsd(avgEth, config.ETH_PRICE_USD);

            md += `| ${func.name} | ${func.avg.toLocaleString()} | ${formatNumber(avgEth)} ETH | ${formatUsd(avgUsd)} |\n`;
        });

        md += `\n### 📊 Gas Usage Statistics

| Function | Min Gas | Avg Gas | Median Gas | Max Gas | Test Calls |
|----------|---------|---------|------------|---------|------------|
`;

        contract.functions.forEach(func => {
            md += `| ${func.name} | ${func.min.toLocaleString()} | ${func.avg.toLocaleString()} | ${func.median.toLocaleString()} | ${func.max.toLocaleString()} | ${func.calls} |\n`;
        });

        // Add cost comparison for this contract at different gas prices
        md += `\n### 💰 Cost at Different Gas Prices

#### Deployment Cost
| Gas Price (gwei) | ETH Cost | USD Cost |
|------------------|----------|----------|
`;

        const gasPrices = [1, 5, 10, 20, 50];
        gasPrices.forEach(gasPrice => {
            const ethCost = gasToEth(contract.deployment.cost, gasPrice);
            const usdCost = ethToUsd(ethCost, config.ETH_PRICE_USD);
            md += `| ${gasPrice} | ${formatNumber(ethCost)} ETH | ${formatUsd(usdCost)} |\n`;
        });

        // Show cost comparison for the most expensive function
        if (contract.functions.length > 0) {
            const mostExpensiveFunc = contract.functions.reduce((max, func) =>
                func.avg > max.avg ? func : max
            );

            md += `\n#### ${mostExpensiveFunc.name} Function Call Cost
| Gas Price (gwei) | ETH Cost | USD Cost |
|------------------|----------|----------|
`;

            gasPrices.forEach(gasPrice => {
                const ethCost = gasToEth(mostExpensiveFunc.avg, gasPrice);
                const usdCost = ethToUsd(ethCost, config.ETH_PRICE_USD);
                md += `| ${gasPrice} | ${formatNumber(ethCost)} ETH | ${formatUsd(usdCost)} |\n`;
            });
        }

        md += `\n---\n\n`;
    });

    md += `## 📝 Notes

- **Gas Price:** Current analysis uses ${config.GAS_PRICE_GWEI} gwei. Actual costs may vary based on network conditions.
- **ETH Price:** USD calculations based on ETH price of $${config.ETH_PRICE_USD}.
- **Deployment Costs:** One-time costs for deploying contracts to the blockchain.
- **Function Costs:** Per-call costs for executing contract functions.

---

*Report generated by Gas Cost Analysis Tool on ${timestamp}*
`;

    return md;
}

/**
 * Parse command line arguments
 */
function parseArgs() {
    const args = process.argv.slice(2);
    const config = {};

    for (let i = 0; i < args.length; i++) {
        switch (args[i]) {
            case '--gas-price':
                config.GAS_PRICE_GWEI = parseInt(args[++i]);
                break;
            case '--eth-price':
                config.ETH_PRICE_USD = parseInt(args[++i]);
                break;
            case '--help':
                console.log('🔧 Gas Cost Analysis Tool - Markdown Report Generator');
                console.log('');
                console.log('Usage: node gas-cost-calculator.js [options]');
                console.log('');
                console.log('Options:');
                console.log('  --gas-price <price>  Gas price in gwei (default: 20)');
                console.log('  --eth-price <price>  ETH price in USD (default: 3000)');
                console.log('  --help              Show this help message');
                console.log('');
                console.log('Examples:');
                console.log('  node gas-cost-calculator.js');
                console.log('  node gas-cost-calculator.js --gas-price 10 --eth-price 2000');
                process.exit(0);
        }
    }

    return { config, args };
}

// Main execution function
function main() {
    const { config, args } = parseArgs();

    // Load gas report data
    const gasReportData = loadGasReportData();

    // Generate Markdown report
    const markdownReport = generateMarkdownReport(gasReportData, config);

    // Output to console
    console.log(markdownReport);

    // Auto save to file
    const filename = 'gas-cost-report.md';
    fs.writeFileSync(filename, markdownReport);
    console.log(`\n📁 Markdown report saved to ${filename}`);
}

// If directly running this script
if (require.main === module) {
    main();
}

module.exports = {
    gasToEth,
    ethToUsd,
    generateMarkdownReport,
    loadGasReportData,
    CONFIG
}; 