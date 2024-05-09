# (5)コールドバックアップとリストア：InterSystems製品のデータベースバックアップ種類別のリストア方法について

InterSystems製品を停止できるときに利用できるバックアップ方法です。別サーバに環境を移植するときや、コミュニティエディションから製品版キットのインストール環境にデータベースを移植する場合などにもお使いいただけます。

## バックアップ手順

1. InterSystems製品を停止する
2. バックアップしたいデータベースを退避する
3. InterSystems製品を開始する

## 既存環境から新環境へ移植する場合などの手順

### 移行手順概要

1. 既存環境のInterSystems製品を停止する。

    既存環境の設定など含めて全てを新環境に移植する場合は、以下記事の退避内容をご確認いただき、ご準備ください。

    - [【IRIS】サーバーを移行する際にコピーが必要な設定情報](https://jp.community.intersystems.com/node/498526)

    - [【Caché／Ensemble】サーバーを移行する際にコピーが必要な設定情報を教えてください](https://faq.intersystems.co.jp/csp/faq/result.csp?DocNo=438)

2. 新環境にInterSystems製品をインストールする。

    1.の手順でコピーしていた情報をもとに、新環境の構成を設定します。

3. 新環境のInterSystems製品を停止する。

4. 既存環境のデータベースファイル（.DAT）を新環境の対象となるデータベースディレクトリに配置する（置換する）

    対象：ユーザ用DB

5. 新環境のInterSystems製品を開始する。

6. 一括コンパイルを実行する。

    IRISにログイン（またはターミナルを起動し）以下実行します。
    
    ```
    Do $system.OBJ.CompileAllNamespaces("u")
    ```


### ご参考：データ移行関連アーカイブビデオ

- [動画：InterSystems IRIS へのデータ移行方法](https://jp.community.intersystems.com/node/497566)

    Caché/Ensemble システムから InterSystems IRIS に移行する場合、マイグレーション(インプレース変換)を行うのでなければ現行環境と新環境を一時的に並行稼働させる必要があるかもしれません。
    そのような場合のインストールや構成についての注意点やデータ移行にどのような技術が利用可能かについてご紹介します。
- [動画：InterSystems IRIS へのマイグレーション](https://jp.community.intersystems.com/node/491606)

    Caché/EnsembleからInterSystems IRISへの移行プロセスについて解説しています。
