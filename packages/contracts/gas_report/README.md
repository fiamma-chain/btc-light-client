# Gas Cost Analysis Tool

An automated gas cost analysis tool that extracts gas data from Forge test reports and calculates actual ETH and USD costs for individual contracts and functions.

## 📋 Features

- 🔍 **Auto-parsing** Forge test gas reports
- 💰 **Cost calculation** Calculate ETH and USD costs based on current gas prices
- 📊 **Contract-focused reports** Generate individual contract deployment and function call costs
- ⚙️ **Flexible configuration** Support custom gas prices and ETH prices
- 🔄 **Automation** One-click complete analysis workflow
- 🧹 **Clean output** Automatically cleanup temporary files

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

### 1. Navigate to gas_report directory

```bash
cd packages/contracts/gas_report
```

### 2. Set executable permissions

```bash
chmod +x scripts/analyze-gas-costs.sh
```

### 3. Basic usage

```bash
# Use default settings (5 gwei, $2500 ETH)
./scripts/analyze-gas-costs.sh

# Use custom prices
./scripts/analyze-gas-costs.sh --gas-price 20 --eth-price 3000
```

### 4. View help information

```bash
./scripts/analyze-gas-costs.sh --help
```

## 📊 Output

The script generates a comprehensive Markdown report (`gas-cost-report.md`) including:
- Individual contract deployment costs and sizes
- Per-transaction function call costs in ETH and USD
- Detailed gas usage statistics (min/avg/median/max)
- Cost comparisons at different gas price levels (1-50 gwei)

## 📄 Configuration Options

### Command Line Arguments

| Argument           | Description           | Default |
| ------------------ | --------------------- | ------- |
| `--gas-price GWEI` | Set gas price in gwei | 5       |
| `--eth-price USD`  | Set ETH price in USD  | 2500    |
| `--help`           | Show help message     | -       |

### Modify Default Configuration

You can directly edit the configuration in `gas-cost-calculator.js`:

```javascript
const CONFIG = {
    GAS_PRICE_GWEI: 5,     // Modify default gas price
    ETH_PRICE_USD: 2500,   // Modify default ETH price
    // ...
};
```

## 🔧 Advanced Usage

For manual control or integration into other workflows:

```bash
# Manual step-by-step execution
forge test --gas-report > output.txt
node scripts/parse-forge-report.js output.txt
node scripts/gas-cost-calculator.js --gas-price 10 --eth-price 2800
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
bash -x ./scripts/analyze-gas-costs.sh
```

## 📊 Report Contents

- **Deployment Cost**: One-time contract deployment cost
- **Function Costs**: Per-call transaction costs
- **Gas Statistics**: Min/Avg/Median/Max usage data
- **Price Comparison**: Costs at 1, 5, 10, 20, 50 gwei levels

## 💡 Tips

1. **Gas Price Selection**: 
   - **1-5 gwei**: Low-priority transactions, longer wait times
   - **10-20 gwei**: Standard transactions, reasonable wait times
   - **50+ gwei**: High-priority transactions, fast confirmation

2. **Cost Optimization**: Use the report to identify expensive functions for optimization

3. **Network Planning**: Compare costs across different gas price scenarios

4. **Regular Updates**: Gas prices fluctuate, so update your analysis regularly

## 🔄 Workflow Integration

This tool can be integrated into your development workflow:

```bash
# Change to gas_report directory first
cd packages/contracts/gas_report

# In your CI/CD pipeline
./scripts/analyze-gas-costs.sh --gas-price 10 --eth-price 2800

# For mainnet cost estimation
./scripts/analyze-gas-costs.sh --gas-price 30 --eth-price 3200

# For testnet development
./scripts/analyze-gas-costs.sh --gas-price 1 --eth-price 2000
```

For more detailed usage examples and advanced configurations, check the individual script files. 