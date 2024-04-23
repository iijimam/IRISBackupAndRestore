# (1)バックアップの種類説明と事前確認：InterSystems製品のデータベースバックアップ種類別のリストア方法について

InterSystems製品のバックアップ方法として以下の4種類の方法を選択できます。

- [外部バックアップ](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_methods_ext)（**推奨方法**）

    外部バックアップは主に、論理ディスク・ボリュームの有効な ”スナップショット” を迅速に作成するテクノロジと共に使用します。

    また、バックアップ時、データベースへの書き込みをフリーズさせてからスナップショットを実行します。
    
    >この ”スナップショット” のようなテクノロジは、ストレージアレイからオペレーティング・システム、ディスクの単純なミラーリングに至るまで、さまざまなレベルで存在します。


- [オンライン・バックアップ](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_methods_online)

    InterSystem製品が用意するバックアップ機能を利用する方法で、バックアップ対象に設定した全データベースの使用済ブロックをバックアップする方法です。

    管理ポータルメニューやタスクスケジュールにも含まれるメニューでお手軽ですが、データベースの使用済ブロック数が多くなればなるほどバックアップ時間も長くなりバックアップファイルサイズも大きくなってしまう方法です。

    > バージョン2024.1以降では、実験的機能として[オンラインバックアップの高速化機能](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/DocBook.UI.Page.cls?KEY=HXIHRN_new20241#HXIHRN_new20241_speedscalesec_fob)を提供しています。

- [コールド・バックアップ](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_methods_ext_cold)

    InterSystems製品を停止できる場合に利用できる方法で手順がシンプルです。

- [並行外部バックアップ](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_methods_ext_concurrent)

    データベースファイル（DATファイル）の退避（ファイルコピーのような対退避方法も含）とオンライン・バックアップを組み合わせて利用する方法で、外部バックアップで使用するスナップショットのようなテクノロジが利用できない環境に対して素早くバックアップを取得できる方法です。（オンラインバックアップより高速にバックアップを実行できますが、手順は複雑です。）

本シリーズ記事では、それぞれのバックアップ方法とリストア方法を解説していきますが、その前に **バックアップを取得する前に必ず確認しておきたい事** があります。

それは何でしょうか。


それは、**バックアップを取るデータベースの物理的な整合性が保たれているかどうか** です。

万が一に備えてバックアップをとっていたとしても、バックアップ対象データベースの物理的な整合性が崩れている状態のバックアップはリストア対象として利用できません。

> 物理的な整合性＝ディスク上のデータベース・ブロックの整合性

整合性が崩れた状態のバックアップからリストアを行うことで、データベースをより壊してしまう可能性があり、非常に危険です。

バックアップが正常に成功していることを確認することも重要ですが、最も重要なことは **データベースの整合性が保たれているデータベースをバックアップしているか** ということです。

種類別のバックアップ方法、リストア方法紹介の前に、まずはデータベースの整合性チェックについて確認していきましょう。

## データベースの物理的な整合性チェックツール

整合性チェックは、管理ポータルメニュー（[システムオペレーション] > [データベース] > [整合性チェックボタン]）や[^Integrity](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_integrity#GCDI_integrity_verify_utility) 、タスクスケジュールを使用して実行することができます。

管理ポータルメニューは以下の通りです。

![](/assets/Integrit-Portal.png)


システムルーチン：[^Integrity](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_integrity#GCDI_integrity_verify_utility) を使用する場合は、IRISにログインし%SYSネームスペースに移動します。

チェックしたいデータベースを指定した実行もできますが、まずはシステム全体のチェックを実行してみます。


カレントデバイスに出力することもできますが、整合性チェックのログは長くなるので、例ではファイル出力先をフルパスで指定しています。


```
USER>set $namespace="%SYS"

%SYS>do ^Integrity

This utility is used to check the integrity of a database
and the pointer structure of one or more globals.

Output results on
Device: /usr/irissys/mgr/integ0424.log
Parameters? "WNS" =>
Stop after any error?  No=>
Do you want to check all databases?  No=> yes
```

ログ例は以下の通りです。

> 整合性チェックは全てのデータベースブロックについての検査結果を出力する長いログのため、一部省略＋コメントを追記しています。
```
Intersystems IRIS Database Integrity Check on 04/08/2024 at 15:23:20
System: 733fea287670  Configuration: IRIS
IRIS for UNIX (Ubuntu Server LTS for x86-64 Containers) 2024.1 (Build 263U) Wed Mar 13 2024 15:21:28 EDT


《コメント》データベースディレクトリ毎に中身に含まれるデータベースブロックのつながりを検査します。

---Directory /usr/irissys/mgr/---

Global: %
 トップ/ボトムポインタレベル: ブロック数=1      8kb (充填率 0%)
 データレベル:           ブロック数=2      16kb (充填率 79%)
 合計:                ブロック数=3      24kb (充填率 53%)
 経過時間 = 0.2 秒 04/08/2024 15:23:26

Global: %IRIS.SASchema
 トップ/ボトムポインタレベル: ブロック数=1      8kb (充填率 0%)
 データレベル:           ブロック数=1      8kb (充填率 11%)
 合計:                ブロック数=2      16kb (充填率 5%)
 経過時間 = 0.2 秒 04/08/2024 15:23:26

＜省略＞

Global: rOBJ
 トップ/ボトムポインタレベル: ブロック数=1      8kb (充填率 37%)
 データレベル:           ブロック数=205      1,640kb (充填率 73%)
 ビッグストリング:          ブロック数=1,374      10MB (充填率 81%) カウント = 539
 合計:                ブロック数=1,580      12MB (充填率 80%)
 経過時間 = 0.2 秒 04/08/2024 15:23:40

---Total for directory /usr/irissys/mgr/---
        95 Pointer Level blocks         760kb (16% full)
     6,634 Data Level blocks             51MB (83% full)
     1,574 Big String blocks             12MB (79% full) # = 696
     8,318 Total blocks                  64MB (81% full)
     1,279 Free blocks                10232kb

Elapsed time = 14.3 seconds 04/08/2024 15:23:40

《コメント》データベースディレクトリに対してチェックが終わると上記サマリを出力し、エラーがない場合は以下出力します。

No Errors were found in this directory.


《コメント》次のデータベースに対する整合性チェックを開始します。

---Directory /usr/irissys/mgr/HSCUSTOM/---

Global: EnsDICOM.Dictionary
 トップ/ボトムポインタレベル: ブロック数=1      8kb (充填率 0%)
 データレベル:           ブロック数=1      8kb (充填率 0%)
 合計:                ブロック数=2      16kb (充填率 0%)
 経過時間 = 0.2 秒 04/08/2024 15:23:40

＜省略＞

Global: rOBJ
 トップ/ボトムポインタレベル: ブロック数=1      8kb (充填率 2%)
 データレベル:           ブロック数=19      152kb (充填率 76%)
 ビッグストリング:          ブロック数=259      2,072kb (充填率 60%) カウント = 259
 合計:                ブロック数=279      2,232kb (充填率 61%)
 経過時間 = 0.1 秒 04/08/2024 15:23:47

---Total for directory /usr/irissys/mgr/HSCUSTOM/---
        48 Pointer Level blocks         384kb (11% full)
     2,150 Data Level blocks             16MB (70% full)
       272 Big String blocks           2176kb (60% full) # = 272
     2,485 Total blocks                  19MB (67% full)
       203 Free blocks                 1624kb

Elapsed time = 7.6 seconds 04/08/2024 15:23:47

No Errors were found in this directory.

《コメント》以降同様にデータベース毎にチェックを行い、エラーがある場合はその対象ブロックに対してエラー情報を出力します。エラーがない場合は各データベースのチェックの終わりに「No Errors were found in this directory.」と出力します。

すべてのデータベースの検査を終え、エラーがない事を確認すると以下1行出力し、整合性チェックが終了します。

No Errors were found.
```

タスクスケジュールについては、インストール時に毎週月曜日深夜2時に実行するタスクとして登録されていますが、一時停止状態で登録されています。

**管理ポータル > [システムオペレーション] > [タスクマネージャ] > [タスクスケジュール] > Integrity Check**
![](/assets/Integrit-Task.png)

整合性チェックは指定したデータベースの全データベースブロックを検査するため、チェック時間は、データ量、チェックするデータベース数、HWスペックに依存します。

目安となるような計測時間は特になく、**実際稼働中の環境で実測した値を参考に予測していただく必要があります。**

万が一の場合に備え、データベース整合性チェック時間のおおよその検討が付けられるように、実環境でテスト実行を行っていただくことを推奨します。

また、整合性チェック時間は環境により異なりますので、実稼働環境の状況に合わせ実行のタイミングをご検討ください。

もし、整合性チェックでエラーが出た場合は、すぐにサポートセンターまでご連絡ください。

以上、整合性チェックツールの使い方でした。

次は、いよいよバックアップ種類別のバックアップとリストア方法について解説します。
