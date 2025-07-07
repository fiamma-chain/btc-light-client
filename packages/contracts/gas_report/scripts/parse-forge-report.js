#!/usr/bin/env node

/**
 * Forge Gas Report Parser
 * Parse forge test --gas-report output and generate JSON format gas data
 */

const fs = require('fs');
const path = require('path');

/**
 * Parse forge test output
 */
function parseForgeOutput(outputText) {
    const lines = outputText.split('\n');
    const contracts = [];
    let currentContract = null;
    let inTable = false;
    let isDeploymentSection = false;
    let isFunctionSection = false;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();

        // Match contract table start
        const contractMatch = line.match(/^╭.*?([A-Za-z]+).*?Contract.*?╮?$/);
        if (contractMatch || line.includes('Contract')) {
            // Try to extract contract name from current line or next line
            let contractName = '';
            if (line.includes('Contract')) {
                const nameMatch = line.match(/src\/([A-Za-z]+)\.sol:([A-Za-z]+)\s+Contract/);
                if (nameMatch) {
                    contractName = nameMatch[2];
                }
            }

            if (contractName) {
                currentContract = {
                    name: contractName,
                    deployment: { cost: 0, size: 0 },
                    functions: []
                };
                contracts.push(currentContract);
                inTable = true;
                isDeploymentSection = false;
                isFunctionSection = false;
            }
            continue;
        }

        if (!currentContract || !inTable) continue;

        // Match deployment cost section
        if (line.includes('Deployment Cost') || line.includes('Deployment Size')) {
            isDeploymentSection = true;
            continue;
        }

        // Match deployment data row
        if (isDeploymentSection && line.match(/^\|\s*\d+/)) {
            const parts = line.split('|').map(p => p.trim()).filter(p => p);
            if (parts.length >= 2) {
                currentContract.deployment.cost = parseInt(parts[0]) || 0;
                currentContract.deployment.size = parseInt(parts[1]) || 0;
                isDeploymentSection = false;
            }
            continue;
        }

        // Match function name header row
        if (line.includes('Function Name')) {
            isFunctionSection = true;
            continue;
        }

        // Match function data row
        if (isFunctionSection && line.startsWith('|') && !line.includes('─')) {
            const parts = line.split('|').map(p => p.trim()).filter(p => p);
            if (parts.length >= 6) {
                const functionData = {
                    name: parts[0],
                    min: parseInt(parts[1]) || 0,
                    avg: parseInt(parts[2]) || 0,
                    median: parseInt(parts[3]) || 0,
                    max: parseInt(parts[4]) || 0,
                    calls: parseInt(parts[5]) || 0
                };
                currentContract.functions.push(functionData);
            }
            continue;
        }

        // Table end
        if (line.includes('╰') && inTable) {
            inTable = false;
            isDeploymentSection = false;
            isFunctionSection = false;
        }
    }

    return contracts;
}

/**
 * Generate JSON data file
 */
function generateJsonDataFile(contracts) {
    const data = {
        metadata: {
            generatedAt: new Date().toISOString(),
            contractCount: contracts.length,
            totalFunctions: contracts.reduce((sum, c) => sum + c.functions.length, 0)
        },
        contracts: contracts
    };

    return JSON.stringify(data, null, 2);
}

/**
 * Main function
 */
function main() {
    const args = process.argv.slice(2);

    if (args.length === 0) {
        console.log('Usage:');
        console.log('  node parse-forge-report.js <forge-output-file>');
        console.log('  forge test --gas-report | node parse-forge-report.js --stdin');
        console.log('');
        console.log('Examples:');
        console.log('  forge test --gas-report > output.txt && node parse-forge-report.js output.txt');
        process.exit(1);
    }

    let inputText = '';

    if (args[0] === '--stdin') {
        // Read from stdin
        process.stdin.setEncoding('utf8');
        process.stdin.on('data', (chunk) => {
            inputText += chunk;
        });

        process.stdin.on('end', () => {
            processInput(inputText);
        });
    } else {
        // Read from file
        const filename = args[0];
        if (!fs.existsSync(filename)) {
            console.error(`❌ File not found: ${filename}`);
            process.exit(1);
        }

        inputText = fs.readFileSync(filename, 'utf8');
        processInput(inputText);
    }
}

function processInput(inputText) {
    const contracts = parseForgeOutput(inputText);

    if (contracts.length === 0) {
        console.error('❌ No contract data found in the input');
        process.exit(1);
    }

    const outputDir = path.dirname(process.argv[1]); // Script directory
    const dataDir = path.join(outputDir, '..');

    // Ensure output directory exists
    if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
    }

    // Generate JSON data file
    const jsonDataContent = generateJsonDataFile(contracts);
    const jsonPath = path.join(dataDir, 'gas-report-data.json');
    fs.writeFileSync(jsonPath, jsonDataContent);

    console.log('✅ Generated JSON data file');
    console.log(`📁 Location: ${jsonPath}`);
    console.log('');
    console.log('📊 Parsed gas report data successfully!');
    console.log(`   Found ${contracts.length} contracts:`);
    contracts.forEach(contract => {
        console.log(`   - ${contract.name} (${contract.functions.length} functions)`);
    });
}

if (require.main === module) {
    main();
}

module.exports = {
    parseForgeOutput,
    generateJsonDataFile
}; 