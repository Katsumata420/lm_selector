# lm_selector
- This script is forked from [@lukeorland's implementation](https://github.com/lukeorland/moore_and_lewis_data_selection).
- README written in Japanese is `README_jp.md`.

## Diff
- This script is aim to select in-domain data for monolingual corpus. 
- We use KenLM for N-gram LM.  
    - The original implementation uses SRILM.
- We use the difference of cross entropy (the log probability normalized by the sentence length) as a selection filter. 
    - The original implementation uses the difference of the perplexity.
- We do not restrict the size of the general domain text in training the general LM.
    - This size is the same as the specific domain text in the original.

## Requirement
- KenLM: https://github.com/kpu/kenlm

## Usage
```
./ml_select.sh \
    GENERAL_DOMAIN_CORPUS \
    SPECIFIC_DOMAIN_CORPUS \
    DEST_DIR \
    [KENLM_BIN_DIR]
```
- `GENERAL_DOMAIN_CORPUS`: tokenized general domain text data; one line one sentence.
- `SPECIFIC_DOMAIN_CORPUS`: tokenized specific domain text data; one line one sentence.
- `DEST_DIR`: path to the directory where the sorted general domain text data is written.
- `[KENLM_BIN_DIR]` (option): path to the directory where the KenLM binary have been compiled in your system. 
    - It assumed by default that this path is `$PATH`.
    - `[KENLM_BIN_DIR]` should be including `lmplz` and `build_binary`.

### Outputs
- `DEST_DIR/sorted-uniq-scores_general.tsv`: TSV file; f1 is difference of the cross entropy and f2 is each sentence.
- `DEST_DIR/general_corpus_sorted.txt`: sorted general domain text.

### Example
```
./ml_select.sh \
    /path/to/general-domain.txt \
    /path/to/specific-domain.txt \
    selection_result \
    /path/to/kenlm_bin
```

## Caution
- We use `sort -n -r` as a sorting command. 
    - If you have a necessary to use the E notation, use `sort -n -r -g` at line 163. 

## Cite
This soting method is implementation of the following paper.
```
Intelligent Selection of Language Model Training Data.
Moore and Lewis., ACL2010
```

Original README is following.
# Description #

This script applies Moore and Lewis's approach to [intelligently selecting
training data](http://research.microsoft.com/apps/pubs/default.aspx?id=138756)
to domain adaptation of translation models for machine translation.

The result of running this script is a copy of a randomly-ordered
general-domain corpus, sorted such that the sentences at the top are most
"similar" to the domain-specific data and the least "similar" sentences are at
the bottom. It is then possible to subsample by selecting the first N sentences
from the sorted files.

This script operates on the type of parallel translation corpora that have two
files, one sentence per line in the source language file, and corresponding
translation appears on each line of the target-side translation file.

The ranking computations can be done on one language side or both. When sorting
bilingually, the ranking of a training sentence pair is its sum of rankings for
both languages.

# Usage #

A recommended first step is to tokenize and normalize the general-domain
training data and domain-specific data before processing them with this script.

## Command format ##

    ./ml_select.sh \
        GENERAL_DOMAIN_CORPUS_PREFIX \
        SPECIFIC_DOMAIN_CORPUS_PREFIX \
        DEST_DIR \
        SOURCE_LANG \
        TARGET_LANG \
        RANK_BY_SOURCE_LANG \
        RANK_BY_TARGET_LANG \
        [ SRILM_BIN_DIR ]

### Parameters ###

* `GENERAL_DOMAIN_CORPUS_PREFIX`

  This is the path to the pair of (normalized, tokenized) parallel
  general-domain files, with the final "." and language extension removed
  (e.g. `.fr`, `.en`). The is the corpus that will be resorted.

  E.g. if the general-domain files are located at

      /path/to/general-domain.lc.tok.fr
      /path/to/general-domain.lc.tok.en

  then the value to pass for this parameter is

      /path/to/general-domain.lc.tok.fr

* `SPECIFIC_DOMAIN_CORPUS_PREFIX`

  This is the path to the (pair of) (normalized, tokenized) parallel
  specific-domain files, with the final "." and language extension removed
  (e.g. `.fr`, `.en`). The general-domain corpus is resorted by similarity to
  this corpus.

  E.g. if the specific-domain files are located at

      /path/to/specific-domain.lc.tok.fr
      /path/to/specific-domain.lc.tok.en

  then the value to pass for this parameter is

      /path/to/general-domain.lc.tok

* `DEST_DIR`

  The path to the existing directory where the sorted general-domain files
  should be written

* `SOURCE_LANG`

  The (probably two-letter) file extension of the source language.

  E.g. for the examples above, the value to pass for this parameter is `fr`.

* `TARGET_LANG`

  The (probably two-letter) file extension of the target language.

  E.g. for the examples above, the value to pass for this parameter is `en`.

* `RANK_BY_SOURCE_LANG`

  Whether to calculate the specific domain's language model's perplexity for
  each source-language sentence in the general-domain.

  The value to pass is either `true` or `false`.

* `RANK_BY_TARGET_LANG`

  Whether to calculate the specific domain's language model's perplexity for
  each target-language sentence in the general-domain.

  The value to pass is either `true` or `false`.

* `[ SRILM_BIN_DIR ]` (optional)

  This parameter specifies the path to the directory where the SRILM binary
  tools (e.g. `ngram`, `ngram-count`) have been compiled in your system. It
  assumed by default that this location is the directory `$SRILM/bin/i686_m64`,
  where `SRILM` is a system variable that has been assigned to the path to the
  SRILM source code directory.

## Example command invocation ##

    ./ml_select.sh \
        /path/to/general-domain.lc.tok \
        /path/to/specific-domain.lc.tok \
        /path/to/destination_directory \
        fr \
        en \
        false \
        true \
        $HOME/code/srilm/bin/i686_m64

## Notes ##

The two parallel files in a corpus should have the same path prefix, and the
filename extension should be the language abbreviations followed by a period
(e.g. `.fr`, `.en`).

After calling the above command, the general-domain corpus is sorted,
duplicates are removed, and the result is copied into the two files such as the
following:

    /dest/dir/general_corpus_sorted.es
    /dest/dir/general_corpus_sorted.en


# How it works

This Bash script takes the following steps to accomplish its task.

## Calculate perplexity difference ##

The following computation process is performed first on the source-language
side, then on the target-language side if desired.

1.  Extract the vocabulary from the specific-domain corpus. The vocabulary
    consists of all non-singleton types.

1.  Randomly select the equivalent number of segments from the the general
    domain as in the specific domain for building a language model.

1.  Build a language model from general-domain text, with vocabulary restricted
    by non-singleton tokens from the specific-domain corpus.

1.  Build a language model from specific-domain text, with vocabulary
    restricted by non-singleton tokens from the specific-domain corpus.

1.  Calculate the perplexity of the general-domain LM for the general-domain
    text segment.

1.  Calculate the perplexity of the specific-domain LM for the general-domain
    text segment.

1.  Subtract the perplexity of the general-domain LM from the perplexity of the
    specific-domain LM for each sentence

## Sum the two differences together if doing bilingual ranking ##

1.  Combine perplexity differences, unprocessed/raw source-, and target-side
    text segments into a single file and print these rows and colums out to a
    tab-delimited file.

1.  Add together the perplexity differences for both target- and
    source-languages

## Sort the general domain lines by ranking ##

1.  Sort training data by the (summed) perplexity difference scores and delete
    consecutive duplicate training candidates.
1.  Write separated source- and target-language training corpus files in sorted
    order.

# TODO #

* Sort files aligned by Berkeley Aligner or GIZA++

