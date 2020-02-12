
set -eu
set -x

# moses script for escape char
if [[ ! -e ./escape-special-chars.perl ]]; then
    wget https://raw.githubusercontent.com/moses-smt/mosesdecoder/master/scripts/tokenizer/escape-special-chars.perl
fi

if [[ ! -e ./deescape-special-chars.perl ]]; then
    wget https://raw.githubusercontent.com/moses-smt/mosesdecoder/master/scripts/tokenizer/deescape-special-chars.perl
fi
