# Gas Cost Analysis Tool

An automated gas cost analysis tool that extracts gas data from Forge test reports and calculates actual ETH and USD costs.

## 📋 Features

- 🔍 **Auto-parsing** Forge test gas reports
- 💰 **Cost calculation** Calculate ETH and USD costs based on current gas prices
- 📊 **Detailed reports** Generate formatted Markdown cost analysis reports
- ⚙️ **Flexible configuration** Support custom gas prices and ETH prices
- 🔄 **Automation** One-click complete analysis workflow
- 📁 **Clean output** Automatically cleanup temporary files

## 🛠️ Requirements

Ensure your system has the following tools installed:

1. **Foundry** (includes forge command)
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Node.js** (v14 or higher)
   ```bash
   # Using nvm
   nvm install node
   # Or download from: https://nodejs.org/
   ```

## 📦 File Structure

```
gas_report/
├── scripts/
│   ├── analyze-gas-costs.sh      # Main automation script
│   ├── gas-cost-calculator.js    # Cost calculator
│   └── parse-forge-report.js     # Forge output parser
└── README.md                     # Documentation
```

## 🚀 Quick Start

### 1. Set executable permissions

```bash
chmod +x gas_report/scripts/analyze-gas-costs.sh
```

### 2. Basic usage

Run in your Forge project directory:

```bash
# Use default settings (20 gwei, $3000 ETH)
./gas_report/scripts/analyze-gas-costs.sh

# Use custom prices
./gas_report/scripts/analyze-gas-costs.sh --gas-price 50 --eth-price 3500
```

### 3. View help information

```bash
./gas_report/scripts/analyze-gas-costs.sh --help
```

## 📊 Sample Output

After running the script, you'll see a detailed Markdown report like:

```markdown
# 📊 Gas Cost Analysis Report

> **Generated on:** 12/30/2024  
> **Configuration:** Gas Price = 20 gwei, ETH Price = $3000  
> **Timestamp:** 2024-12-30T07:22:12.644Z

---

## 📋 Executive Summary

- **Total Contracts:** 2
- **Total Deployment Cost:** 0.071237 ETH ($213.7100)
- **Total Functions:** 6

---

## 1. BtcMirror Contract

### 📦 Deployment Information

| Metric            | Value        |
| ----------------- | ------------ |
| **Gas Used**      | 1,456,824    |
| **ETH Cost**      | 0.029136 ETH |
| **USD Cost**      | $87.4096     |
| **Contract Size** | 6967 bytes   |

### ⚡ Function Call Costs

| Function Name | Avg Gas | ETH Cost     | USD Cost | Calls |
| ------------- | ------- | ------------ | -------- | ----- |
| getBlockHash  | 2,835   | 0.000057 ETH | $0.1701  | 14    |
| submit        | 68,544  | 0.001371 ETH | $4.1126  | 10    |

### 💡 Usage Scenarios

**Typical Scenario:** Deploy + 10 submit calls
- **Total ETH Cost:** 0.042846 ETH
- **Total USD Cost:** $128.5380
```

## 📄 Configuration Options

### Command Line Arguments

| Argument           | Description           | Default |
| ------------------ | --------------------- | ------- |
| `--gas-price GWEI` | Set gas price in gwei | 20      |
| `--eth-price USD`  | Set ETH price in USD  | 3000    |
| `--help`           | Show help message     | -       |

### Modify Default Configuration

You can directly edit the configuration in `gas-cost-calculator.js`:

```javascript
const CONFIG = {
    GAS_PRICE_GWEI: 20,    // Modify default gas price
    ETH_PRICE_USD: 3000,   // Modify default ETH price
    // ...
};
```

## 🔧 Advanced Usage

### 1. Manual Forge Output Parsing

```bash
# Generate forge report
forge test --gas-report > my-report.txt

# Parse report
node scripts/parse-forge-report.js my-report.txt

# Generate cost analysis
node scripts/gas-cost-calculator.js
```

### 2. Pipeline Operations

```bash
# Parse directly from forge output
forge test --gas-report | node scripts/parse-forge-report.js --stdin
```

## 📁 Output Files

The script generates the following files:

- **`gas-cost-report.md`** - Complete Markdown format report
- **Temporary files** are automatically cleaned up after generation

## 🛠️ Troubleshooting

### Common Issues

1. **"Forge is not installed"**
   - Solution: Install Foundry toolchain

2. **"No gas report data found"**
   - Check if you're in the correct Forge project directory
   - Ensure test files exist and can run normally

3. **"parse-forge-report.js not found"**
   - Ensure all script files are in the correct directory
   - Check file permissions

### Debug Mode

Run with verbose output to see detailed execution steps:

```bash
bash -x ./gas_report/scripts/analyze-gas-costs.sh
```

## 📊 Understanding the Report

### Report Sections

1. **Executive Summary** - Overview of all contracts and total costs
2. **Contract Details** - Individual contract deployment and function costs
3. **Usage Scenarios** - Typical usage cost estimates
4. **Cost Analysis** - Comparison at different gas price levels
5. **Function Breakdown** - Visual representation of function costs
6. **Detailed Metrics** - Complete statistical data

### Key Metrics

- **Deployment Cost**: One-time cost to deploy the contract
- **Function Call Cost**: Per-transaction cost for each function
- **Gas Usage**: Raw gas consumption numbers
- **ETH Cost**: Converted cost in ETH based on gas price
- **USD Cost**: Final cost in USD based on ETH price

## 💡 Tips

1. **Regular Updates**: Gas prices fluctuate, so update your analysis regularly
2. **Network Conditions**: Mainnet gas prices can vary significantly from testnets
3. **Optimization**: Use the report to identify high-cost functions for optimization
4. **Scenario Planning**: The usage scenarios help estimate real-world costs

## 🔄 Workflow Integration

This tool can be integrated into your development workflow:

```bash
# In your CI/CD pipeline
./gas_report/scripts/analyze-gas-costs.sh --gas-price 30 --eth-price 2500
```

For more detailed usage examples and advanced configurations, check the individual script files. 