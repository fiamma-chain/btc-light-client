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
    GAS_PRICE_GWEI: 20,

    // ETH price (USD)
    ETH_PRICE_USD: 3000,

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

## 📋 Executive Summary

`;

    // Calculate total cost
    let totalDeploymentCostEth = 0;
    let totalDeploymentCostUsd = 0;

    gasReportData.contracts.forEach(contract => {
        const deploymentEth = gasToEth(contract.deployment.cost, config.GAS_PRICE_GWEI);
        const deploymentUsd = ethToUsd(deploymentEth, config.ETH_PRICE_USD);
        totalDeploymentCostEth += deploymentEth;
        totalDeploymentCostUsd += deploymentUsd;
    });

    md += `- **Total Contracts:** ${gasReportData.contracts.length}
- **Total Deployment Cost:** ${formatNumber(totalDeploymentCostEth)} ETH (${formatUsd(totalDeploymentCostUsd)})
- **Total Functions:** ${gasReportData.contracts.reduce((sum, c) => sum + c.functions.length, 0)}

---

`;

    // Generate detailed information for each contract
    gasReportData.contracts.forEach((contract, index) => {
        const deploymentEth = gasToEth(contract.deployment.cost, config.GAS_PRICE_GWEI);
        const deploymentUsd = ethToUsd(deploymentEth, config.ETH_PRICE_USD);

        md += `## ${index + 1}. ${contract.name} Contract

### 📦 Deployment Information

| Metric | Value |
|--------|-------|
| **Gas Used** | ${contract.deployment.cost.toLocaleString()} |
| **ETH Cost** | ${formatNumber(deploymentEth)} ETH |
| **USD Cost** | ${formatUsd(deploymentUsd)} |
| **Contract Size** | ${contract.deployment.size} bytes |

### ⚡ Function Call Costs

| Function Name | Avg Gas | ETH Cost | USD Cost | Calls |
|---------------|---------|----------|----------|-------|
`;

        contract.functions.forEach(func => {
            const avgEth = gasToEth(func.avg, config.GAS_PRICE_GWEI);
            const avgUsd = ethToUsd(avgEth, config.ETH_PRICE_USD);

            md += `| ${func.name} | ${func.avg.toLocaleString()} | ${formatNumber(avgEth)} ETH | ${formatUsd(avgUsd)} | ${func.calls} |\n`;
        });

        // Usage scenario analysis
        md += `\n### 💡 Usage Scenarios

`;

        if (contract.name === "BtcMirror") {
            const submitFunc = contract.functions.find(f => f.name === "submit");
            if (submitFunc) {
                const scenarioCost = deploymentEth + (gasToEth(submitFunc.avg, config.GAS_PRICE_GWEI) * 10);
                const scenarioUsd = ethToUsd(scenarioCost, config.ETH_PRICE_USD);

                md += `**Typical Scenario:** Deploy + 10 submit calls
- **Total ETH Cost:** ${formatNumber(scenarioCost)} ETH
- **Total USD Cost:** ${formatUsd(scenarioUsd)}

`;
            }
        } else if (contract.name === "BtcTxVerifier") {
            const verifyFunc = contract.functions.find(f => f.name === "verifyPayment");
            if (verifyFunc) {
                const scenarioCost = deploymentEth + (gasToEth(verifyFunc.avg, config.GAS_PRICE_GWEI) * 100);
                const scenarioUsd = ethToUsd(scenarioCost, config.ETH_PRICE_USD);

                md += `**Typical Scenario:** Deploy + 100 verification calls
- **Total ETH Cost:** ${formatNumber(scenarioCost)} ETH
- **Total USD Cost:** ${formatUsd(scenarioUsd)}

`;
            }
        }

        md += `---

`;
    });

    // Cost comparison table
    md += `## 🔥 Cost Analysis at Different Gas Prices

| Gas Price (gwei) | Total Deployment Cost (ETH) | Total Deployment Cost (USD) |
|------------------|------------------------------|------------------------------|
`;

    const gasPrices = [1, 5, 10, 20, 50];
    const totalDeploymentGas = gasReportData.contracts.reduce((sum, contract) => sum + contract.deployment.cost, 0);

    gasPrices.forEach(gasPrice => {
        const ethCost = gasToEth(totalDeploymentGas, gasPrice);
        const usdCost = ethToUsd(ethCost, config.ETH_PRICE_USD);
        md += `| ${gasPrice} | ${formatNumber(ethCost)} ETH | ${formatUsd(usdCost)} |\n`;
    });

    md += `
---

## 📈 Function Cost Breakdown

`;

    // Create function cost chart data for each contract
    gasReportData.contracts.forEach(contract => {
        md += `### ${contract.name} Functions (by Average Gas Usage)

`;

        // Sort by gas usage
        const sortedFunctions = [...contract.functions].sort((a, b) => b.avg - a.avg);

        sortedFunctions.forEach((func, index) => {
            const avgEth = gasToEth(func.avg, config.GAS_PRICE_GWEI);
            const avgUsd = ethToUsd(avgEth, config.ETH_PRICE_USD);

            // Create simple ASCII bar chart
            const maxGas = sortedFunctions[0].avg;
            const barLength = Math.ceil((func.avg / maxGas) * 20);
            const bar = '█'.repeat(barLength) + '░'.repeat(20 - barLength);

            md += `${index + 1}. **${func.name}**  
   \`${bar}\` ${func.avg.toLocaleString()} gas (${formatUsd(avgUsd)})

`;
        });
    });

    md += `---

## 🔍 Detailed Metrics

### Gas Usage Statistics

`;

    gasReportData.contracts.forEach(contract => {
        md += `#### ${contract.name}

| Function | Min Gas | Avg Gas | Median Gas | Max Gas | Calls |
|----------|---------|---------|------------|---------|-------|
`;

        contract.functions.forEach(func => {
            md += `| ${func.name} | ${func.min.toLocaleString()} | ${func.avg.toLocaleString()} | ${func.median.toLocaleString()} | ${func.max.toLocaleString()} | ${func.calls} |\n`;
        });

        md += `\n`;
    });

    md += `---

## 📝 Notes

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