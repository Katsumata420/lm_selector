# lm_selector
- このスクリプトは [@lukeorland さんの実装](https://github.com/lukeorland/moore_and_lewis_data_selection)を元にしたものです。

## 差分
- このスクリプトは単言語データに対して実行することを想定しています。
- このスクリプトは N-gram LM 推定に KenLM を使用しています。
- データ選択の際に、エントロピーの差分を用いています。
    - 元にした実装ではパープレキシティの差分を用いていました。
- 一般分野の言語モデルを構築する際、使用する文数に制限を設けていません。
    - 元実装では目的分野のデータに合わせて一般分野のデータを制限していました。

## 依存関係
- KenLM: https://github.com/kpu/kenlm

## 使い方
```
./ml_select.sh \
    GENERAL_DOMAIN_CORPUS \
    SPECIFIC_DOMAIN_CORPUS \
    DEST_DIR \
    [KENLM_BIN_DIR]
```
- `GENERAL_DOMAIN_CORPUS`: 単語分割された一般分野のデータ（e.g. Wikipedia）; 1行1文
- `SPECIFIC_DOMAIN_CORPUS`: 単語分割された目的分野のデータ; 1行1文
- `DEST_DIR`: 出力先ディレクトリ
- `[KENLM_BIN_DIR]（オプション）`: KenLM へのパス; `lmplz` と `build_binary` が入ってる path

### 出力
- `DEST_DIR/sorted-uniq-scores_general.tsv`: TSV file; f1 がエントロピーの差分で、f2が文
- `DEST_DIR/general_corpus_sorted.txt`: エントロピーの差分でソートされた文

### 例
```
./ml_select.sh \
    /path/to/general-domain.txt \
    /path/to/specific-domain.txt \
    selection_result \
    /path/to/kenlm_bin
```

## 注意
- ソート時に、`sort -n -r` を実行している（line 163）
    - ソート結果を細かい刻みで使用したい場合は、`sort -n -r -g` に変更しないと指数表記が一番上に行ってしまう。
    - 大きい刻みで、指数表記が上に行っても行かなくてもフィルタ結果が変わらない場合はそのままで良い

## 引用
このスクリプトは以下の論文を元に実装したものです。
```
Intelligent Selection of Language Model Training Data.
Moore and Lewis., ACL2010
```
