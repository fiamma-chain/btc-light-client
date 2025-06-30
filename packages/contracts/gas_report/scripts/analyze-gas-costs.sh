#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
GAS_PRICE_GWEI=5
ETH_PRICE_USD=2500

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --gas-price)
            GAS_PRICE_GWEI="$2"
            shift 2
            ;;
        --eth-price)
            ETH_PRICE_USD="$2"
            shift 2
            ;;
        --help)
            echo "🔧 Gas Cost Analysis Tool"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --gas-price <price>  Gas price in gwei (default: $GAS_PRICE_GWEI)"
            echo "  --eth-price <price>  ETH price in USD (default: $ETH_PRICE_USD)"
            echo "  --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                  # Generate Markdown report with default settings"
            echo "  $0 --gas-price 10 --eth-price 2000 # Custom prices"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🔧 Gas Cost Analysis Tool"
echo "========================="
print_status "Configuration:"
echo "  • Gas Price: $GAS_PRICE_GWEI gwei"
echo "  • ETH Price: $ETH_PRICE_USD USD"
echo ""

# Step 1: Run forge test with gas report
print_status "Running forge test with gas reporting..."

# Change to the contracts directory (where foundry.toml is located)
CONTRACT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"
cd "$CONTRACT_DIR"

if ! forge test --gas-report > "$SCRIPT_DIR/../forge-output.txt" 2>&1; then
    print_error "forge test failed"
    echo "Output:"
    cat "$SCRIPT_DIR/../forge-output.txt"
    exit 1
fi

print_success "forge test completed successfully"

# Step 2: Parse gas report data
print_status "Parsing gas report data..."
if ! node "$SCRIPT_DIR/parse-forge-report.js" "$SCRIPT_DIR/../forge-output.txt"; then
    print_error "Failed to parse gas report"
    exit 1
fi

print_success "Gas report data parsed successfully"

# Step 3: Generate Markdown report
print_status "Generating Markdown report..."

if ! node "$SCRIPT_DIR/gas-cost-calculator.js" \
    --gas-price "$GAS_PRICE_GWEI" \
    --eth-price "$ETH_PRICE_USD"; then
    print_error "Failed to generate Markdown report"
    exit 1
fi

print_success "Markdown report generated successfully!"
print_status "Report saved to: $CONTRACT_DIR/gas-cost-report.md"

# Step 4: Clean up temporary files
rm -f "$SCRIPT_DIR/../forge-output.txt"
rm -f "$SCRIPT_DIR/../gas-report-data.json"

echo ""
print_success "Analysis completed! 🎉" 