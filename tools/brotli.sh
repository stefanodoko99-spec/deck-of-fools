#!/bin/sh
# Brotli-compress a file at the highest setting: tools/brotli.sh <in> <out>.
# Uses the brotli command when installed, otherwise Node's built-in zlib.
set -eu
if command -v brotli >/dev/null 2>&1; then
	brotli -q 11 -w 24 -f -o "$2" "$1"
else
	node -e "const z=require('zlib'),fs=require('fs');const [i,o]=process.argv.slice(1);const b=fs.readFileSync(i);fs.writeFileSync(o,z.brotliCompressSync(b,{params:{[z.constants.BROTLI_PARAM_QUALITY]:11,[z.constants.BROTLI_PARAM_LGWIN]:24,[z.constants.BROTLI_PARAM_SIZE_HINT]:b.length}}))" "$1" "$2"
fi
