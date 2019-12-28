#!/bin/bash

set -u
set -e
set -o pipefail

MIN_NUM_EXPECTED_ARGS=3  # or 8, if the final argument is passed
MAX_NUM_EXPECTED_ARGS=4  # or 8, if the final argument is passed
KENLM=$PATH
USAGE="$0 \\
    GENERAL_DOMAIN_CORPUS \\
    SPECIFIC_DOMAIN_CORPUS \\
    DEST_DIR \\
    [ KENLM_BIN_DIR ]"

if [ "$#" -lt "$MIN_NUM_EXPECTED_ARGS" ]; then
    echo -e "Arguments error. usage:\n$USAGE"
    exit 2
fi

if [ "$#" -gt "$MAX_NUM_EXPECTED_ARGS" ]; then
    echo -e "Arguments error. usage:\n$USAGE"
    exit 2
fi

GENERAL_DOMAIN_CORPUS=$1
SPECIFIC_DOMAIN_CORPUS=$2
DEST_DIR=$3

# Default location of srilm compiled binaries
if [ "$#" == "$MAX_NUM_EXPECTED_ARGS" ]; then
    KENLM_BIN_DIR=$4
else
    KENLM_BIN_DIR="$KENLM/bin"
fi
echo "KENLM_BIN_DIR=$KENLM_BIN_DIR"

if [ -z "$KENLM_BIN_DIR" ]; then
    echo -e "Arguments error. usage:\n$USAGE"
    exit 2
fi

temp_dir=$DEST_DIR/temp
num_specific_segs=$(cat $SPECIFIC_DOMAIN_CORPUS | wc -l)

echo >&2
echo "--- Clearing the temporary directory." >&2
rm -rf $temp_dir
mkdir -p $temp_dir
rm -f $DEST_DIR/sorted_training.txt

# Copy corpora, insert space at the beginning of each line to prevent srilm
# from ignoring a line with a hash character at the beginning.

# general-domain corpus
cat $GENERAL_DOMAIN_CORPUS \
 | sed '/^$/d' \
 > $temp_dir/copied_general_domain_corpus.txt
# specific-domain corpus
cat $SPECIFIC_DOMAIN_CORPUS \
 | sed '/^$/d' \
 > $temp_dir/copied_specific_domain_corpus.txt

# delete the vocab extracting
# for lang in $calc_languages; do
#   echo >&2
#   echo "--- Extracting the vocabulary from" >&2
#   echo "--- the specific-domain corpus..." >&2
  # Only words that appeared more than once go into the vocab.
#   $KENLM_BIN_DIR/ngram-count -text $temp_dir/copied_specific_domain_corpus_prefix.$lang -write-order 1 -write $temp_dir/specific_$lang.1cnt
#   awk \
#       '$2 > 1' \
#       $temp_dir/specific_$lang.1cnt \
#     | cut -f1 \
#     | sort \
#     > $temp_dir/specific_$lang.vocab
# done

# delete equivalent segment
# --- Selecting the equivalent number of segments 
# --- of the general domain as in the specific domain for building a 
# --- language model.
# for lang in $calc_languages; do
#   echo >&2
#   echo "--- Selecting the equivalent number of segments from the $lang-side" >&2
#   echo "--- of the general domain as in the specific domain for building a " >&2
#   echo "--- language model." >&2
#   head -n $num_specific_segs $temp_dir/copied_general_domain_corpus_prefix.$lang \
#     > $temp_dir/general_lm_training_segments.$lang
# done

for domain in general specific; do
    echo >&2
    echo "--- Building a language model from $domain-domain text," >&2
    echo "--- with vocabulary restricted by non-singleton tokens from the in-domain corpus." >&2
    if [ "$domain" == "specific" ]; then
      text=$temp_dir/copied_specific_domain_corpus.txt
    else
      text=$temp_dir/copied_general_domain_corpus.txt
    fi
    $KENLM_BIN_DIR/lmplz \
      -o 5 \
      -T ./ \
      -S 30G \
      --prune 0 0 1 \
       < $text \
      > $temp_dir/lm_${domain}.arpa
    
    $KENLM_BIN_DIR/build_binary \
    $temp_dir/lm_${domain}.arpa \
    $temp_dir/lm_${domain}.bin
done

# calculate sentence length
echo >&2
echo " --- calc sentence length for deviding the log prob by it" >&2
python calc_sentlength.py $temp_dir/copied_general_domain_corpus.txt \
    > $temp_dir/sent_length.txt


for domain in general specific; do
    echo >&2
    echo "--- Calculating the perplexity of the general-domain text segment " >&2
    echo "--- against the $domain LM." >&2
    $KENLM_BIN_DIR/query \
        -v sentence \
        $temp_dir/lm_${domain}.bin \
        < $temp_dir/copied_general_domain_corpus.txt \
      | grep "Total" \
      | awk '{print $2}' \
      > $temp_dir/logprob_${domain}.txt

    paste $temp_dir/logprob_${domain}.txt $temp_dir/sent_length.txt \
    | awk -F '\t' '{print $1 / $2}' \
    > $temp_dir/logprob_${domain}.sentlength.txt
done


echo >&2
echo "--- Subtracting (the log prob of the general text against the" >&2
echo "--- general-domain LM)" >&2
echo "--- from (the log prob of the general text against the" >&2
echo "--- specific-domain LM)" >&2
paste $temp_dir/logprob_specific.sentlength.txt \
      $temp_dir/logprob_general.sentlength.txt \
 | awk -F '\t' '{print $1 - $2}' \
 > $temp_dir/logprob_diff.txt

rankfile=$temp_dir/logprob_diff.txt

echo >&2
echo "--- Sorting training data by log prob difference scores" >&2
echo "--- and deleting consecutive duplicate training candidates." >&2
# Combine score with source segment and target segment.
cat $rankfile \
  | paste - $temp_dir/copied_general_domain_corpus.txt \
  > $temp_dir/scores_general.tsv

# Then sort in ascending orders (largest number is high prob against
# general-domain LM and much lower prob against specific-domain LM).
# Then delete consecutive duplicates.
cat $temp_dir/scores_general.tsv \
	| sort -n -r \
	| uniq \
  > $temp_dir/sorted-uniq-scores_general.tsv

# Then write source and target training corpus files in sorted order.
echo >&2
echo "--- Writing source and target training corpus files in sorted order." >&2
cut -f2 $temp_dir/sorted-uniq-scores_general.tsv \
    > $DEST_DIR/general_corpus_sorted.txt

cp $temp_dir/sorted-uniq-scores_general.tsv $DEST_DIR

rm -rf $temp_dir
