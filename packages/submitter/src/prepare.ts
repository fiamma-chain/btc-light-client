function bitsToTarget(bitsHex: string): string {
    // bits is a 4 bytes value
    // First byte is exponent
    // The last 3 bytes are coefficient/mantissa
    const bytes = new Array(4);
    for (let i = 0; i < 4; i++) {
        bytes[i] = parseInt(bitsHex.slice(i * 2, (i + 1) * 2), 16);
    }

    // But bitcoin use little-endian, so we need reverse to obtain the data.
    bytes.reverse();

    // Get exponent from last byte
    const exp = bytes[0];
    
    // Get mantissa from first three bytes
    let mantissa = bytes[1];
    mantissa = (mantissa << 8) | bytes[2];
    mantissa = (mantissa << 8) | bytes[3];

    console.log(`exponent: ${exp}`);
    console.log(`coefficient: ${mantissa}`);
    
    let target = BigInt(mantissa * Math.pow(2, 8 * (exp - 3)));
    let targetHex = target.toString(16);
    while (targetHex.length < 64) {
        targetHex = '0' + targetHex;
    }
    
    return targetHex;
}

function main() {
    const bits = process.argv[2];
    
    const target = bitsToTarget(bits);
    console.log(`target: ${target}`);
}
  
main();