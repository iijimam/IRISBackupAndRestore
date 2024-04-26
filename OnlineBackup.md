# (3)オンラインバックアップとリストア：InterSystems製品のデータベースバックアップ種類別のリストア方法について

InterSystems製品のバックアップ種別の「オンラインバックアップ」は、InterSystem製品が用意するバックアップ機能を利用する方法で、バックアップ対象に設定した全データベースの**使用済ブロック**をバックアップする方法です。


InterSystems製品のデータベースには、サーバ側で記述したコード、テーブル定義／クラス定義、データ（レコード、永続オブジェクト、グローバル）が格納されていますので、これらすべてが1つのファイルにバックアップされます。

![](/assets/Online-BackupFile.png)


**データ量が増えればバックアップファイルサイズも大きくなります。
また、データ量の増加に伴いバックアップ時間も長くなります。**

バックアップ時間に制限のない環境や、ユーザからのアクセスがない環境（例：ディザスタリカバリの目的で配置しているミラーリングの非同期メンバ）のバックアップ方法としては最適ですが、バックアップ時間に制限がある場合は不向きです。

バックアップ時間をできるだけ短くしたい場合は、推奨方法である「[外部バックアップ](/ExternalBackup.md)」や、手順が少し複雑になりますが「並行外部バックアップ」を取り入れるなどご検討ください。

> 外部バックアップもオンラインでバックアップが行えますが、バックアップ方法が異なります。

- [オンラインバックアップの仕組み](#オンラインバックアップの仕組み)
- [オンラインバックアップの事前準備](#オンラインバックアップの事前準備)
- [オンラインバックアップの種類](#オンラインバックアップの種類)
- [オンラインバックアップの取得方法](#オンラインバックアップの取得方法)
- [リストア方法](#リストア方法)

## オンラインバックアップの仕組み

ユーザプロセスが停止しない仕組みを作るため、オンラインバックアップでは、3つのパスに分けてバックアップを実行しています。

データベースリストに複数のデータベースが含まれている場合は、パス毎にすべてのデータベースのバックアップを実行します。

- 最初のパス

    全てのブロックのバックアップや、その時点で更新が発生したブロックを追跡し、バックアップ・ビットマップに記録し、全ブロックをバックアップします。

- 2番目～n番目のパス

    前の処理以降に変更のあったブロックを処理します。このパスは変更ブロックが少なくなるまで実行されます。

- 最後のパス

    最後のパスが完了するまでの間、ライトデーモン（WRTDMN）を一時停止させます。


以下、2つのデータベースをデータベースリストに設定したときのフルバックアップ時のログです。

最初のパス

```
*** The time is: 2024-04-25 09:42:06 ***

              InterSystems IRIS Backup Utility
              --------------------------------
Performing a Full backup.
Backing up to device: /usr/irissys/mgr/backup/FullDBList_20240425_001.cbk
Description
Full backup of all databases that are in the backup database list.


Backing up the following directories:
 /usr/irissys/mgr/t1/
 /usr/irissys/mgr/user/


Journal file switched to:
/usr/irissys/mgr/journal/20240425.002


Starting backup pass 1
Backing up /usr/irissys/mgr/t1/ at 04/25/2024 09:42:07
Copied 14083 blocks in 0.287 seconds

Finished this pass of copying /usr/irissys/mgr/t1/

Backing up /usr/irissys/mgr/user/ at 04/25/2024 09:42:07
Copied 194 blocks in 0.007 seconds

Finished this pass of copying /usr/irissys/mgr/user/

Backup pass 1 complete at 04/25/2024 09:42:07
```

それぞれデータベースの全てのバックアップ対象ブロックをバックアップファイルコピーしていることがわかります。

また、バックアップを開始する前にジャーナルファイルを切り替えていることが確認できます。

次に、2番目のパスです。

```
Starting backup pass 2
Backing up /usr/irissys/mgr/t1/ at 04/25/2024 09:42:08
Copied 1 blocks in 0.001 seconds

Finished this pass of copying /usr/irissys/mgr/t1/

Backing up /usr/irissys/mgr/user/ at 04/25/2024 09:42:08
Copied 1 blocks in 0.002 seconds

Finished this pass of copying /usr/irissys/mgr/user/

Backup pass 2 complete at 04/25/2024 09:42:08
```

2番目以降も、それぞれのデータベースの全ての変更ブロックをバックアップファイルにコピーしていることがわかります。

次は、最後のパスです。

```
Starting backup pass 3

Journal file '/usr/irissys/mgr/journal/20240425.002' and the subsequent ones are required for recovery purpose if the backup were to be restored

Journal marker set at
offset 198264 of /usr/irissys/mgr/journal/20240425.002

 - This is the last pass - Suspending write daemon
Backing up /usr/irissys/mgr/t1/ at 04/25/2024 09:42:10
Copied 1 blocks in 0.002 seconds

Finished this pass of copying /usr/irissys/mgr/t1/

Backing up /usr/irissys/mgr/user/ at 04/25/2024 09:42:10
Copied 1 blocks in 0.002 seconds

Finished this pass of copying /usr/irissys/mgr/user/

Backup pass 3 complete at 04/25/2024 09:42:10

***FINISHED BACKUP***

Global references are enabled.

Backup complete.

```

最後のパスでは、` - This is the last pass - Suspending write daemon` のログがあり、ライトデーモン（WRTDMN）を一次停止させ全てのブロックをバックアップしていることがわかります。

3つのパスは以下で解説するオンラインバックアップの種類に関わらず必ず実行されます。

## オンラインバックアップの種類

オンラインバックアップには、フルバックアップ／累積バックアップ／差分バックアップの３種類のバックアップ方法があります。


バックアップ時間については、フルバックアップよりも累積バックアップ、累積バックアップよりも差分バックアップが短くなりますが、累積バックアップと差分バックアップを行うためには、必ず事前にフルバックアップを取得する必要があります。

なるべくバックアップ時間が短くなるように３種類のバックアップ方法を組み合わせて利用する事もできます。

累積バックアップ・差分バックアップの違いや組み合わせ例については、コミュニティの記事「[累積バックアップと差分バックアップの違いについて](https://jp.community.intersystems.com/node/490151)」をご参照ください。


## オンラインバックアップの事前準備

データベースのバックアップリストを作成する必要があります。

作成は、管理ポータルから、またはAPIから作成できます。

- 管理ポータルから作成する場合

    **管理ポータル > [システム管理] > [構成] > [データベースバックアップ] > [データベース・バックアップ・リスト]** で設定します。

    ![](/assets/OnlineBackupList.png)

- APIで作成する場合

    [BackUp.General](https://docs.intersystems.com/irisforhealthlatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME=Backup.General)の[AddDatabaseToList()](https://docs.intersystems.com/irisforhealthlatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME=Backup.General#AddDatabaseToList)／[ClearDatabaseList()](https://docs.intersystems.com/irisforhealthlatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME=Backup.General#ClearDatabaseList)／[RemoveDatabaseFromList()](https://docs.intersystems.com/irisforhealthlatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME=Backup.General#RemoveDatabaseFromList)を利用します。
    

    管理ポータルのデータベースリストを一旦クリアし、データベースUSERとT1を追加する例は以下の通りです。(%SYSネームスペースで実行します) 

    実行が成功するとステータスOKとして1が返ります（$$$OK）。

    ```
    // 既存のデータベースリストをクリアする
    set status=##class(Backup.General).ClearDatabaseList()
    write status

    // T1とUSERをデータベースリストに追加する。
    set status=##class(Backup.General).AddDatabaseToList("USER")
    write status
    set status=##class(Backup.General).AddDatabaseToList("T1")
    write status
    ```



## オンラインバックアップの取得方法

管理ポータルには、手動で行うバックアップメニューとタスクスケジュールに設定しておけるバックアップメニューがあります。

プログラムから実行する場合は、[BACKUP^DBACKルーチン](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_util_DBACK_entrypoints)を使用します。

以下順序で解説します。

- [1. 管理ポータルのバックアップメニュー](#1管理ポータルのバックアップメニュー)
- [2. 管理ポータルのタスクスケジュール](#2管理ポータルのタスクジュール)
- [3. ^BACKUPルーチン](#3backupルーチン)
- [4. BACKUP^DBACKルーチン](#4backupdback)

※上記方法で実行する前にバックアップ対象データベースを「バックアップリスト」に指定する必要があります。詳しくは[オンラインバックアップの事前準備](#オンラインバックアップの事前準備)をご参照ください。


### 1.管理ポータルのバックアップメニュー

**管理ポータル > [システムオペレーション] > [バックアップ]** からバックアップを実行できます。

![](/assets/PortalMenu.png)

メニューの「すべてのデータベースのフルバックアップ」は、インストール環境のすべてのデータベースをバックアップします。

**データベースリストで指定したデータベースのバックアップを行う場合は「フルバックアップのリスト」のメニューを選択してください。**

以下、実際のバックアップを実行する画面です。画面内の「バックアップを保存するデバイス」に出力可能なディレクトリを指定してから実行してください。

![](/assets/MP-FullBackup.png)


バックアップログは「ログファイル」の場所に配置されます。

### 2.管理ポータルのタスクジュール

新しいタスクを作成するときに、オンラインバックアップ用タイプを指定してタスクを設定します。

**管理ポータル > [システムオペレーション] > [タスクマネージャ] > [新しいタスク]**

タイプは以下の通りです。

- リストデータベースのインクリメンタルバックアップ
- リストデータベースのフルバックアップ
- リストデータベースの累積差分バックアップ

![](/assets/Task-OnlineBackup.png)

後は日時指定を行えば、指定の時刻に対象のバックアップを開始できます。

### 3.^BACKUPルーチン

システムルーチン^BACKUPは%SYSネームスペースに移動して実行します。

**【注意】** バックアップ実行結果のログ出力を指定できないため、画面ログなどをご利用ください。

メニュー詳細についてはドキュメント「[^BACKUP によるバックアップおよびリストアのタスクの実行](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_util_BACKUP)」をご参照ください。

以下ルーチン実行例です。

`Start the Backup (y/n)? => y` 以降は前述：[オンラインバックアップの仕組み](#オンラインバックアップの仕組み) で説明した各バックアップパスのログが出力されます。

```
%SYS>do ^BACKUP


1) Backup
2) Restore ALL
3) Restore Selected or Renamed Directories
4) Edit/Display List of Directories for Backups
5) Abort Backup
6) Display Backup volume information
7) Monitor progress of backup or restore

Option? 1


*** The time is: 2024-04-25 17:18:19 ***

              InterSystems IRIS Backup Utility
              --------------------------------
What kind of backup:
   1. Full backup of all in-use blocks
   2. Incremental since last backup
   3. Cumulative incremental since last full backup
   4. Exit the backup program
1 => 1
Specify output device (type STOP to exit)
Device: /usr/irissys/mgr/backup/FullDBList_20240425_001.cbk => /usr/irissys/mgr/backup/FullDBList_20240425_002.cbk
Backing up to device: /usr/irissys/mgr/backup/FullDBList_20240425_002.cbk
Description: ^BACKUPルーチンを利用したフルバックアップの実行


Backing up the following directories:
 /usr/irissys/mgr/t1/
 /usr/irissys/mgr/user/


Start the Backup (y/n)? => y
Journal file switched to:
/usr/irissys/mgr/journal/20240425.003


Starting backup pass 1
Backing up /usr/irissys/mgr/t1/ at 04/25/2024 17:19:11
Copied 14083 blocks in 0.288 seconds

Finished this pass of copying /usr/irissys/mgr/t1/

Backing up /usr/irissys/mgr/user/ at 04/25/2024 17:19:12
Copied 371 blocks in 0.017 seconds

Finished this pass of copying /usr/irissys/mgr/user/

Backup pass 1 complete at 04/25/2024 17:19:12

Starting backup pass 2
Backing up /usr/irissys/mgr/t1/ at 04/25/2024 17:19:14
Copied 1 blocks in 0.002 seconds

Finished this pass of copying /usr/irissys/mgr/t1/

Backing up /usr/irissys/mgr/user/ at 04/25/2024 17:19:14
Copied 1 blocks in 0.002 seconds

Finished this pass of copying /usr/irissys/mgr/user/

Backup pass 2 complete at 04/25/2024 17:19:14

Starting backup pass 3

Journal file '/usr/irissys/mgr/journal/20240425.002' and the subsequent ones are required for recovery purpose if the backup were to be restored

Journal marker set at
offset 197596 of /usr/irissys/mgr/journal/20240425.003

 - This is the last pass - Suspending write daemon
Backing up /usr/irissys/mgr/t1/ at 04/25/2024 17:19:15
Copied 1 blocks in 0.003 seconds

Finished this pass of copying /usr/irissys/mgr/t1/

Backing up /usr/irissys/mgr/user/ at 04/25/2024 17:19:15
Copied 1 blocks in 0.005 seconds

Finished this pass of copying /usr/irissys/mgr/user/

Backup pass 3 complete at 04/25/2024 17:19:15

***FINISHED BACKUP***

Global references are enabled.

Backup complete.


1) Backup
2) Restore ALL
3) Restore Selected or Renamed Directories
4) Edit/Display List of Directories for Backups
5) Abort Backup
6) Display Backup volume information
7) Monitor progress of backup or restore

Option?   //Enter押下
%SYS>
```

### 4.BACKUP^DBACK

システムルーチン^DBACKルーチンのBACKUPプロシージャを利用して、プログラムからバックアップを実行することができます。

引数詳細はドキュメント「[BACKUP^DBACK](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_util_DBACK_entry_backup)」をご参照ください。

- フルバックアップ

    第2引数はフルバックアップのタイプである"F"を指定します。
    
    第4引数はバックアップファイル名

    第6引数はバックアップログのファイル名

    第5、8、9はバックアップ開始後にジャーナルを切り替えるための指定のため"Y"（切り替える）を推奨しています。

    第7引数は、実行時のカレントデバイスへの出力指定

    ```
    set modori=$$BACKUP^DBACK("","F","フルバックアップの実行","/usr/irissys/mgr/backup/FullBackUp-DBACK-20240425.cbk","Y","/usr/irissys/mgr/backup/FullBackUp-DBACK-20240425.log","QUIET","Y","Y")
    ```

- 累積バックアップ

    フルバックアップの実行例の第2引数に"C"を指定します。

- 差分バックアップ

    フルバックアップの実行例の第2引数に"I"を指定します。

## リストア方法

リストアは、システムルーチン[^DBREST](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_util_DBREST)を利用する方法と、プログラムから実行する方法を選択できます。

リストアは**リストア時の確認項目が多いため、テスト環境などでリストアテストを実施いただくことを強く推奨します。**

リストアにかかる時間についても、HW構成、リストア対象データベース数、データ量に依存するためリストアテストを行った際の計測値から予測いただくこととなります。

それでは、具体的な方法をご説明します。

- [システムルーチンを利用したリストア（手動）](#システムルーチンを利用したリストア手動)
- [プログラムによるリストア](#プログラムによるリストア)


### システムルーチンを利用したリストア（手動）

システムルーチン[^DBREST](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_util_DBREST)を利用します。

> または、^BACKUPルーチンの 2) Restore ALL または 3) Restore Selected or Renamed Directories からも実行できます。

```
%SYS>do ^DBREST

                        Cache DBREST Utility
         Restore database directories from a backup archive

Restore: 1. All directories
         2. Selected and/or renamed directories
         3. Display backup volume information
         4. Exit the restore program
    1 =>
```
リストアメニューについては、

- 1. All directories

    バックアップファイルに含まれるデータベースすべてをリストアします。

    画面表示例はドキュメント：[^DBRESTによるすべてのデータベースのリストア](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_util_DBREST_all)をご参照ください。

- 2. Selected and/or renamed directories

    バックアップファイルに含まれる一部のデータベースだけをリストアしたい場合、また、バックアップ時点のデータベースディレクトリと異なるディレクトリにリストアを行う場合に使用します。

    参考ドキュメント：[^DBREST による選択したデータベースまたは名前を変更したデータベースのリストア](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_util_DBREST_select) 


以下の例では、「2. Selected and/or renamed directories」を使用して、バックアップファイルに含まれるデータベースを選択肢、別ディレクトリのデータベースにリストアする手順を説明します。

#### リストア実行例（データベースディレクトリ変更）

例ではバックアップファイルに以下データベースが含まれています。
- USERデータベース＝ /usr/irissys/mgr/user
- T1データベース＝/usr/irissys/mgr/t1

以下例では、T1データベースのあるディスクが壊れたことを想定し、リストア時のT1データベースディレクトリがバックアップ時点とは異なるディレクトリにリストアしなくてはならない場合の流れで解説します。

なお、バックアップファイルのリストア後、ジャーナルファイルを利用したリストアも行う必要がありますので以下の流れで試していきます。

![](/assets/Ex-T1.png)

- [1、バックアップ前にT1データベースに任意データ登録する（^prebackup=1）](#1バックアップ前にt1データベースに任意データ登録するprebackup1)
- [2、フルバックアップを実行する](#2フルバックアップを実行する)
- [3、切り替わったジャーナルファイル名を確認する](#3切り替わったジャーナルファイル名を確認する)
- [4、バックアップ後だとわかる任意データをT1データベースに登録する（^postbackup=1）](4、バックアップ後だとわかる任意データをT1データベースに登録する（^postbackup=1）)

- [5、ジャーナルファイルに 4で登録した情報が含まれているか確認する](#5ジャーナルファイルに-4で登録した情報が含まれているか確認する)
- [6、T1データベース（/usr/irissys/mgr/t1）を削除](#6t1データベースusririssysmgrt1を削除)

![](/assets/Ex-T1rest.png)
- [7、T1データベースを別ディレクトリ（/usr/irissys/mgr/t1rest）に再作成](#7t1データベースを別ディレクトリusririssysmgrt1restに再作成)
- [8、バックアップからのリストアを実行する](#8バックアップからのリストアを実行する)

    T1データベースのみリストアするように指定します。
    - バックアップ時点のディレクトリ：/usr/irissys/mgr/t1
    - リストア時に指定するディレクトリ：/usr/irissys/mgr/t1rest

- [9、^prebackup=1 が戻ることを確認する](#9prebackup1-が戻ることを確認する)
- [10、ジャーナルリストアを実行](#10ジャーナルリストアを実行)

    T1データベースのみリストアするように指定します。
    - バックアップ時点のディレクトリ：/usr/irissys/mgr/t1
    - リストア時に指定するディレクトリ：/usr/irissys/mgr/t1rest
- [11、^postbackup=1 が戻ることを確認する](#11postbackup1-が戻ることを確認する)

---

##### 1、バックアップ前にT1データベースに任意データ登録する（^prebackup=1）

ネームスペースT1に接続し、以下実行します。

Linuxやコンテナを利用されている場合は、`iris session インスタンス名 -U T1`でログインすると簡単です。

```
set $namespace="T1"
set ^prebackup=1
```
管理ポータルでデータを確認します。

**[システムエクスプローラ] > [グローバル] > T1ネームスペース選択**

![](/assets/Online-prebackup.png)


グローバル変数名が多く一覧される場合、画面左端の「フィルタ」の「グローバル名」に`pre*` と書くとフィルタされた結果が表示されます。

##### 2、フルバックアップを実行する

[オンラインバックアップの取得方法](#オンラインバックアップの取得方法)のいずれかの方法を利用してフルバックアップを実行します。

例では管理ポータルメニューを利用しています。

![](/assets/Online-Ex-Fullbackup.png)

以下の例で使用するバックアップファイル名は「/usr/irissys/mgr/Backup/FullDBList_20240426_001.cbk」です。

##### 3、切り替わったジャーナルファイル名を確認する

**管理ポータル > [システムオペレーション] > [ジャーナル]** 「バックアップにより」切り替わったジャーナルファイルを確認します。

以下の例でジャーナルリストアの開始ファイルとして指定するファイル名は「/usr/irissys/mgr/journal/20240426.002」です。

##### 4、バックアップ後だとわかる任意データをT1データベースに登録する（^postbackup=1）

ネームスペースT1に接続し、以下実行します。

Linuxやコンテナを利用されている場合は、`iris session インスタンス名 -U T1`でログインすると簡単です。

```
set $namespace="T1"
set ^postbackup=1
```

##### 5、ジャーナルファイルに 4で登録した情報が含まれているか確認する

**管理ポータル > [システムオペレーション] > [ジャーナル]** で現在のジャーナルファイルを開き、^postbackupが記録されているか確認します。

![](/assets/Online-postbackup.png)

画面右端のデータベースディレクトリ名を確認し、「/usr/irissys/mgr/t1」で記録されていることを確認します。

##### 6、T1データベース（/usr/irissys/mgr/t1）を削除

管理ポータルメニューから削除します。

稼働中に削除する場合、一旦データベースをディスマウントすることをお勧めします。

**管理ポータル > [システムオペレーション] > [データベース] > T1を選択 > ディスマウントボタンをクリック**

![](/assets/Online-Ex-Dismount.png)

ディスマウント後、構成メニューに移動しデータベースを削除します。

**管理ポータル > [システム管理] > [構成] > [システム構成] > [ローカルデータベース] > T1を削除**

![](/assets/Online-Ex-DBDelete.png)


##### 7、T1データベースを別ディレクトリ（/usr/irissys/mgr/t1rest）に再作成

管理ポータルでT1ネームスペース、データベースを作成します。

このときのデータベースは最初に作成したディレクトリとは異なるディレクトリで作成します。

例では、**/usr/irissys/mgr/t1rest** としています。

![](/assets/Online-Ex-T1Rest.png)

##### 8、バックアップからのリストアを実行する

システムルーチン^DBRESTの例でご紹介します。

InterSystems製品にログインし、%SYSネームスペースに移動します。

Linuxやコンテナの場合は、`iris session インスタンス名 -U %SYS`で%SYSネームスペースにログインできます。

```
set $namespace="%SYS"
do ^DBREST
```
画面で指定する内容は以下の通りです。


```
%SYS>do ^DBREST

                        Cache DBREST Utility
         Restore database directories from a backup archive

Restore: 1. All directories
         2. Selected and/or renamed directories
         3. Display backup volume information
         4. Exit the restore program
    1 => 2
```

バックアップファイルに含まれるデータベースを選択肢、さらにディレクトリをリダイレクトしてリストアを実行するため、2を選択します。

続いて以下質問されます。
```
Do you want to set switch 10 so that other processes will be
prevented from running during the restore? Yes =>
```
リストア実行中`switch 10`を設定したいか？と聞かれています。`switch 10`を設定すると**カレントプロセス以外の他のプロセスからのRead／Writeを禁止します。**

リストア実行中に他プロセスからのデータ参照・更新を防ぎたいときはYes（デフォルト）を指定します。（推奨）

続いて、バックアップファイルを指定します。管理ポータルからバックアップを行ったため、バックアップ履歴より直近のフルバックアップファイル名を表示しています。ディレクトリに変更がないか確認し正しい場合ははEnterを押下します。

異なる場合は、フルパスでフルバックアップのファイル名を指定します。

最終行にリストアを開始したいか？と質問されるので、Enter（またはYes）を押下します。
```
Specify input file for volume 1 of backup 1
 (Type STOP to exit)
Device: /usr/irissys/mgr/Backup/FullDBList_20240426_001.cbk =>

This backup volume was created by:
   IRIS for UNIX (Ubuntu Server LTS for x86-64 Containers) 2024.1

The volume label contains:
   Volume number      1
   Volume backup      APR 26 2024 11:36AM Full
   Previous backup    APR 25 2024 05:34PM Full
   Last FULL backup   APR 25 2024 05:34PM
   Description        Full backup of all databases that are in the backup database list.
   Buffer Count       0
Is this the backup you want to start restoring? Yes =>
```

続いて、バックアップファイルに含まれるデータベースディレクトリが出力されるので、同じディレクトリにリストアする場合はEnterを押下します。

今回は異なるディレクトリにリダイレクトしたいため、`/usr/irissys/mgr/t1rest`を入力しています。

次に、もう１つのバックアップ対象である`/usr/irissys/mgr/user`のディレクトリが表示されます。リストア対象外に設定したいので、X（大文字）を入力します。

ディレクトリリストを変更したか？と質問されるので、変更不要の場合は、Noを入力します。

```
For each database included in the backup file, you can:

 -- press RETURN to restore it to its original directory;
 -- type X, then press RETURN to skip it and not restore it at all.
 -- type a different directory name.  It will be restored to the directory
    you specify.  (If you specify a directory that already contains a
    database, the data it contains will be lost).

/usr/irissys/mgr/t1/ => /usr/irissys/mgr/t1rest
/usr/irissys/mgr/user/ => X

Do you want to change this list of directories? No => no
```

リストアによりデータベースをオーバーライドするけど良いか？と質問されます。
リストアを開始してよい場合は、yesを入力します。
```
Restore will overwrite the data in the old database. Confirm Restore? No => yes
```
リストアが開始されます。

/usr/irissys/mgr/t1　を /usr/irissys/mgr/t1rest　にリストアし、/usr/irissys/mgr/userはスキップされることが出力されています。
```
***Restoring /usr/irissys/mgr/t1/ to /usr/irissys/mgr/t1rest/ at 13:39:00
14085 blocks restored in 0.4 seconds for this pass, 14085 total restored.

Starting skip of /usr/irissys/mgr/user/.

     skipped 371 blocks in .011176 seconds.

***Restoring /usr/irissys/mgr/t1/ to /usr/irissys/mgr/t1rest/ at 13:39:00
1 blocks restored in 0.0 seconds for this pass, 14086 total restored.

Starting skip of /usr/irissys/mgr/user/.

     skipped 1 blocks in .000005 seconds.

***Restoring /usr/irissys/mgr/t1/ to /usr/irissys/mgr/t1rest/ at 13:39:00
1 blocks restored in 0.0 seconds for this pass, 14087 total restored.

Starting skip of /usr/irissys/mgr/user/.

     skipped 1 blocks in .000005 seconds.

```

さらにバックアップファイルがあるか確認されます。ない場合は STOP を入力します。
```
Specify input file for volume 1 of backup following APR 26 2024  11:36AM
 (Type STOP to exit)
Device: STOP
```
リストアしたいバックアップファイルがあるか再度確認されます。ある場合はYES（デフォルト）ない場合は、Noを入力します。
```
Do you have any more backups to restore? Yes => no
Mounting /usr/irissys/mgr/t1rest/
    /usr/irissys/mgr/t1rest/  ... (Mounted)

```
/usr/irissys/mgr/t1rest　がマウントされました。

通常、リストア対象データベースにはジャーナルファイルのリストアも行いますが、一旦、バックアップ時点に戻ったかどうか確認のため、練習の流れでは 4を選択し、ユーティリティを一旦終了しています。
```
Restoring a directory restores the globals in it only up to the
date of the backup.  If you have been journaling, you can apply
journal entries to restore any changes that have been made in the
globals since the backup was made.

What journal entries do you wish to apply?

     1. All entries for the directories that you restored
     2. All entries for all directories
     3. Selected directories and globals
     4. No entries

Apply: 1 => 4
%SYS>
```
リストア中、`switch 10`の設定により、カレントプロセス以外のREAD/WRITEが禁止されます。リストアを終了する場合、必ずシステムルーチンを終了し、%SYSのプロンプトが表示されている状態に戻してください。


##### 9、^prebackup=1 が戻ることを確認する

**管理ポータル > [システムエクスプローラ] > [グローバル] > T1ネームスペース選択**

^prebackupは表示されますが、^postbackupがまだ戻っていないことを確認します。

##### 10、ジャーナルリストアを実行

続いて、ジャーナルリストアを実行します。

ご参考：[^JRNRESTO を使用したジャーナル・ファイルからのグローバルのリストア](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_journal#GCDI_journal_util_JRNRESTO)

ジャーナルのリストアもジャーナルファイルに記録されている全データベースディレクトリではなく、`/usr/irissys/mgr/t1` で記録されていた情報のみをリストアするようにします。グローバル変数まで指定してリストアできますが、今回は`/usr/irissys/mgr/t1`のグローバルをすべてリストアするようにします。

%SYSネームスペースで^JOURNALルーチンを実行します。

ジャーナルリストアメニューは、4番を選択します。

```
%SYS>do ^JOURNAL


 1) Begin Journaling (^JRNSTART)
 2) Stop Journaling (^JRNSTOP)
 3) Switch Journal File (^JRNSWTCH)
 4) Restore Globals From Journal (^JRNRESTO)
 5) Display Journal File (^JRNDUMP)
 6) Purge Journal Files (PURGE^JOURNAL)
 7) Edit Journal Properties (^JRNOPTS)
 8) Activate or Deactivate Journal Encryption (ENCRYPT^JOURNAL())
 9) Display Journal status (Status^JOURNAL)
10) -not available-
11) -not available-
12) Journal catch-up for mirrored databases (MirrorCatchup^JRNRESTO)
13) -not available-

Option? 4
This utility uses the contents of journal files
to bring globals up to date from a backup.
```
ジャーナルをリストアしますか？には、Yes（またはEnter）を入力します。
```
Restore the Journal? Yes => Yes
```
**この質問の回答が重要です。**
ジャーナルファイルに記録された全データベースディレクトリの全グローバル変数をリストアする場合は、Yesを入力します。

今回は、指定ディレクトリんの全グローバルをリダイレクトしながらリストアしたいので、**no** を入力します。

```
Process all journaled globals in all directories? no
```
別のOSで作成されたジャーナルファイルを使用するか質問されます。使用しない場合はNoを入力します。
```
Are journal files imported from a different operating system? No => No
```
続いて、リストアするデータベースディレクトリを指定します。

`/usr/irissys/mgr/t1` を `/usr/irissys/mgr/t1rest` にリダイレクトしながらリストアします。
```
Directory to restore [? for help]: /usr/irissys/mgr/t1  /usr/irissys/mgr/t1/??
No database exists in that directory.
(you will be required to redirect to another directory)
Redirect to Directory: /usr/irissys/mgr/t1/
 => /usr/irissys/mgr/t1rest--> /usr/irissys/mgr/t1rest/
```
指定したデータベースディレクトリに含まれるすべてのグローバルをリストアしたいですか？と聞かれています。今回は特定のグローバルではなく全てリストアするためyesを指定します。
```
Process all globals in /usr/irissys/mgr/t1/? No => yes
```
さらにリストア対象データベースがある場合は同様に指定しますが、ない場合は、Enterを押下します
```
Directory to restore [? for help]:
```
ここまで指定したディレクトリリストを表示します。変更がなければyesを入力します。
```
Processing globals from the following datasets:
 1. /usr/irissys/mgr/t1/   All Globals
    (Redirect to: /usr/irissys/mgr/t1rest/)

Specifications correct? Yes => yes
```
リストアに使用するジャーナルファイルはこのインスタンスで作成され、ジャーナルディレクトリにあるパスに配置されているかどうか質問されています。（InterSystems製品にはjournal.logファイルがあり、直近までのジャーナルファイルのフルパス情報が記録されています。このファイルを使用できるかどうかの質問です。）

例では、設定どおりにジャーナルファイルが配置されているため、yesを入力します。
```
Are journal files created by this InterSystems IRIS instance and located in their original paths? (Uses journal.log to locate journals)? yes
```
次に、どのジャーナルファイルをリストア対象とするか指定します。ファイル名が不明な場合は ? を入力するとリストを出します。リストから選択することもできます。（例では、First fileとFinal fileが同一ですが問題ありません）

最終行の質問で、次のファイルがある場合はYesを入力しない場合はnoを入力します。
```
Specify range of files to process

Enter ? for a list of journal files to select the first and last files from
First file to process:  ?

1) /usr/irissys/mgr/journal/20240425.003
2) /usr/irissys/mgr/journal/20240425.004
3) /usr/irissys/mgr/journal/20240426.001
4) /usr/irissys/mgr/journal/20240426.002

First file to process:  4 /usr/irissys/mgr/journal/20240426.002
Final file to process:  /usr/irissys/mgr/journal/20240426.002 =>
Prompt for name of the next file to process? No => no
```
ジャーナルファイルのリストに欠落がないかどうかチェックするか質問されます。
Enter（またはYes）を入力します。
```

The following actions will be performed if you answer YES below:

* Listing journal files in the order they will be processed
* Checking for any missing journal file on the list ("a broken chain")

The basic assumption is that the files to be processed are all
currently accessible. If that is not the case, e.g., if you plan to
load journal files from tapes on demand, you should answer NO below.
Check for missing journal files? Yes => Yes

```
処理対象ジャーナルファイルが表示されます。

続いて、ジャーナルファイル内の整合性チェックを行うか確認されます。（デフォルトはNo）例ではNoを選択しています。
```
Journal files in the order they will be processed:
1. /usr/irissys/mgr/journal/20240426.002

While the actual journal restore will detect a journal integrity problem
when running into it, you have the option to check the integrity now
before performing the journal restore. The integrity checker works by
scanning journal files, which may take a while depending on file sizes.
Check journal integrity? No => No
```

リストア処理前後でジャーナルファイルを切り替えるか質問されます。
切り替えたほうがわかりやすいので、例ではYesを指定しています。

```
The journal restore includes the current journal file.
You cannot do that unless you stop journaling or switch
     journaling to another file.
Do you want to switch journaling? Yes => Yes
Journaling switched to /usr/irissys/mgr/journal/20240426.003
```
ジャーナルリストア中のジャーナルを無効化したいか質問されています。デフォルトのYes（無効化）を選択します。

※ミラーリングを利用している場合は無効化を選択せず、リストア中のジャーナルを他メンバーに転送し摘用することで全メンバーのリストアが自動的に完了させることもできます。
```
You may disable journaling of updates for faster restore for all
databases other than mirrored databases. You may not want to do this
if a database to restore is being shadowed as the shadow will not
receive the updates.
Do you want to disable journaling the updates? Yes => Yes
Updates will NOT be journaled
```
リストアを開始する前にデフォルトオプションを確認しています。

デフォルトは、
- データベースに関連するエラーが発生した場合でもリストアを続行します。
- ジャーナルに関連するエラーが発生した場合、リストアを中止します。

別の方法は、
- データベースに関連するエラーが発生した場合中止します。
- ジャーナルファイルに関連する問題が発生した場合でもリストアを続行します。

変更しない場合は、デフォルトのNoを指定します。
```
Before we job off restore daemons, you may tailor the behavior of a
restore daemon in certain events by choosing from the options below:

     DEFAULT:    Continue despite database-related problems (e.g., a target
     database cannot be mounted, error applying an update, etc.), skipping
     updates to that database. Affected database(s) may not be self-consistent
     and will need to be recovered separately

     ALTERNATE:  Abort if an update would have to be skipped due to a
     database-related problem (e.g., a target database cannot be mounted,
     error applying an update, etc.). Databases will be left in a
     self-consistent state as of the record that caused the restore to be
     aborted. Parallel dejournaling will be disabled with this setting

     DEFAULT:    Abort if an update would have to be skipped due to a
     journal-related problem (e.g., journal corruption, some cases of missing
     journal files, etc.)

     ALTERNATE:  Continue despite journal-related problems (e.g., journal
     corruption, some missing journal files, etc.), skipping affected updates

Would you like to change the default actions? No => No
```
リストアを開始する場合は、Yesを入力します。
```
Start the restore? Yes => Yes
```
ジャーナルリストアを開始し、リダイレクト先のデータベースディレクトリが更新されます。

メニューが表示されるので特に他の作業がなければEnterを押下し%SYSネームスペースのプロプト表示に戻ります。
```
Journal file being applied: /usr/irissys/mgr/journal/20240426.002
/usr/irissys/mgr/journal/20240426.002
  0.81% 100.00%
[Journal restore completed at 20240426 14:10:16]

The following databases have been updated:

1. /usr/irissys/mgr/t1rest/


 1) Begin Journaling (^JRNSTART)
 2) Stop Journaling (^JRNSTOP)
 3) Switch Journal File (^JRNSWTCH)
 4) Restore Globals From Journal (^JRNRESTO)
 5) Display Journal File (^JRNDUMP)
 6) Purge Journal Files (PURGE^JOURNAL)
 7) Edit Journal Properties (^JRNOPTS)
 8) Activate or Deactivate Journal Encryption (ENCRYPT^JOURNAL())
 9) Display Journal status (Status^JOURNAL)
10) -not available-
11) -not available-
12) Journal catch-up for mirrored databases (MirrorCatchup^JRNRESTO)
13) -not available-

Option?
%SYS>
```

##### 11、^postbackup=1 が戻ることを確認する

**管理ポータル > [システムエクスプローラ] > [グローバル] > T1ネームスペース選択**

^postbackupが存在するか確認します。

### プログラムによるリストア

- EXTALL^DBREST

    バックアップファイルに含まれるすべてのデータベースをリストアできます。

    また、例では、バックアップファイルに含まれるデータベースのバックアップファイルからのリストアとジャーナルファイルのリストアを行っています。

    引数詳細については、ドキュメントの[^DBRESTによる自動リストア](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_util_DBREST_entrypoints)をご参照ください。

    例では、以下の引数を指定します。
    - 第1引数：1を指定（非インタラクティブモードであることを指定）
    - 第2引数：0を指定（リストア処理中に更新を許可しない）
    - 第3引数：バックアップファイル名を指定
    - 第4引数：このシナリオでは指定なし
    - 第5引数：1を指定（ジャーナルをリストアするためのオプションで、1はバックアップをリストアしたすべてのディレクトリを指定）
    - 第6引数：バックアップリストア後にリストアしたいジャーナルファイル名


    実行例は以下の通りです。
    ```
    %SYS>do EXTALL^DBREST(1,0,"/usr/irissys/mgr/Backup/FullDBList_20240426_001.cbk",,1,"/usr/irissys/mgr/journal/20240426.002",1)

    The following directories will be restored:
    /usr/irissys/mgr/t1/ =>
    /usr/irissys/mgr/user/ =>

    Expanding /usr/irissys/mgr/t1/ from 1 MB to 114 MB

    ***Restoring /usr/irissys/mgr/t1/ at 14:45:30
    14085 blocks restored in 0.8 seconds for this pass, 14085 total restored.

    ***Restoring /usr/irissys/mgr/user/ at 14:45:31
    371 blocks restored in 0.0 seconds for this pass, 371 total restored.

    ***Restoring /usr/irissys/mgr/t1/ at 14:45:31
    1 blocks restored in 0.0 seconds for this pass, 14086 total restored.

    ***Restoring /usr/irissys/mgr/user/ at 14:45:31
    1 blocks restored in 0.0 seconds for this pass, 372 total restored.

    ***Restoring /usr/irissys/mgr/t1/ at 14:45:31
    1 blocks restored in 0.0 seconds for this pass, 14087 total restored.

    ***Restoring /usr/irissys/mgr/user/ at 14:45:31
    1 blocks restored in 0.0 seconds for this pass, 373 total restored.

    Mounting /usr/irissys/mgr/t1/
        /usr/irissys/mgr/t1/  ... (Mounted)

    Mounting /usr/irissys/mgr/user/
        /usr/irissys/mgr/user/  ... (Mounted)


    We know something about where journaling was at the time of the backup:
    0: offset 196976 in /usr/irissys/mgr/journal/20240426.002


    /usr/irissys/mgr/journal/20240426.002


    Journal reads completed. Applying changes to databases...
    20.00%  40.00%  60.00%  80.00% 100.00%100.00%
    ***Journal file finished at 14:45:33
    ```

- EXTSELCT^DBREST
    
    バックアップファイルに含まれるデータベースディレクトリを指定したリストア、またディレクトリ先を指定したリストアが行えます。

    以下の実行例は、`/usr/irissys/mgr/t1` で記録されていた情報を `/usr/irissys/mgr/t1rest` にリストアしています。

    このラベル名からのジャーナルリストは、リダイレクト先が指定できません。以下の例では、バックアップからのリストアだけで終了するようにしています。

    例では、以下の引数を指定します。
    - 第1引数：1を指定（非インタラクティブモードであることを指定）
    - 第2引数：0を指定（リストア処理中に更新を許可しない）
    - 第3引数：バックアップファイル名を指定
    - 第4引数：リストア先ディレクトリを含むファイル名
        
        ファイルには、以下指定します。
        ```
        ソースディレクトリ,ターゲットディレクトリ,ターゲットディレクトリが存在しないとき作成するかどうかのY/Nのどちらか
        ```
    - 第5引数：4を指定（ジャーナルリストア指定しない）


    事前に第4引数のファイルを準備します。ファイルには以下の記載をしています。

    ```
    $ cat restdir.txt
    /usr/irissys/mgr/t1/,/usr/irissys/mgr/t1rest/,N
    ```

    以下実行例です。バックアップファイルから `/usr/irissys/mgr/t1` を `/usr/irissys/mgr/t1rest` にリダイレクトしてリストアしていますが、ジャーナルリストアは行われていません。

    ```
    %SYS>do EXTSELCT^DBREST(1,0,"/usr/irissys/mgr/Backup/FullDBList_20240426_001.cbk","/usr/irissys/mgr/Backup/restdir.txt",4)

    ***Restoring /usr/irissys/mgr/t1/ to /usr/irissys/mgr/t1rest/ at 15:06:39
    14085 blocks restored in 0.2 seconds for this pass, 14085 total restored.

    Starting skip of /usr/irissys/mgr/user/.

        skipped 371 blocks in .006246 seconds.

    ***Restoring /usr/irissys/mgr/t1/ to /usr/irissys/mgr/t1rest/ at 15:06:39
    1 blocks restored in 0.0 seconds for this pass, 14086 total restored.

    Starting skip of /usr/irissys/mgr/user/.

        skipped 1 blocks in .00001 seconds.

    ***Restoring /usr/irissys/mgr/t1/ to /usr/irissys/mgr/t1rest/ at 15:06:39
    1 blocks restored in 0.0 seconds for this pass, 14087 total restored.

    Starting skip of /usr/irissys/mgr/user/.

        skipped 1 blocks in .000008 seconds.

    Mounting /usr/irissys/mgr/t1rest/
        /usr/irissys/mgr/t1rest/  ... (Mounted)

    [Journal not applied to any directory]

    %SYS>
    ```

    現時点では、`/usr/irissys/mgr/t1rest` のデータベースには ^postbackupが存在しませんん。

    選択したデータベースディレクトリをリダイレクトしながらジャーナルリストアを行うには、[Journal.Restore](https://docs.intersystems.com/irisforhealthlatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME=Journal.Restore)クラスを利用します。

#### ジャーナルファイルのリストア

ジャーナルファイルに記録されている `/usr/irissys/mgr/t1`の情報を`/usr/irissys/mgr/t1rest`にリストアする例でご紹介します。

サンプルコード：[ZRestore.Journal](/ZRestore/Journal.cls)

メソッド、プロパティの使い方についてはコメント文をご確認ください。
```
    set jrnrest=##class(Journal.Restore).%New()

    #;リストアのジャーナルファイルを指定します
    #; CurrentFileは以下メソッドで取得可
    #; ##class(%SYS.Journal.System).GetCurrentFile().Name
    set jrnrest.FirstFile="/usr/irissys/mgr/journal/20240426.002"
    #;LastFileの指定がない場合は最後のファイルまでリストアします
    set jrnrest.LastFile="/usr/irissys/mgr/journal/20240426.002"

    #;ジャーナルディレクトリの設定（カレントインスタンスのジャーナルを利用する場合の例）
    #; UseJournalLocation()　ジャーナルディレクトリを指定するメソッド
    #; 現在のプライマリディレクトリの場所を指定する場合は、メソッドで場所を特定できる
    set location1=##class(%SYS.Journal.System).GetPrimaryDirectory()
    do jrnrest.UseJournalLocation(location1)
    set location2=##class(%SYS.Journal.System).GetAlternateDirectory()
    do jrnrest.UseJournalLocation(location2)

    #; ソースDBとターゲットDBの指定
    #; ディレクトリは全て小文字で記載する＋末尾のパスのマーク必須
    set source="/usr/irissys/mgr/t1/"
    set target="/usr/irissys/mgr/t1rest/"
    #; リストア対象データベースの指定
    //$$$ThrowOnError(jrnrest.SelectUpdates(source))
    set status=jrnrest.SelectUpdates(source)
    if $system.Status.IsError(status) {
        write $system.Status.GetErrorText(status)
    }
    #; リダイレクト先の指定 
    //$$$ThrowOnError(jrnrest.RedirectDatabase(source,target))
    set status=jrnrest.RedirectDatabase(source,target)
    if $system.Status.IsError(status) {
        write $system.Status.GetErrorText(status)
    }
    #; ジャーナルの整合性チェック
    //$$$ThrowOnError(jrnrest.CheckJournalIntegrity(1))
    set status=jrnrest.CheckJournalIntegrity(1) 
    if $system.Status.IsError(status) {
        write $system.Status.GetErrorText(status)
    }
    #; リストア実行
    //$$$ThrowOnError(jrnrest.Run())
    set status=jrnrest.Run()
    if $system.Status.IsError(status) {
        write $system.Status.GetErrorText(status)
    }
```

サンプルコード：[ZRestore.Journal](/ZRestore/Journal.cls)実行例
```
%SYS>set status=##class(ZRestore.Journal).RedirectTest()

Journal file being applied: /usr/irissys/mgr/journal/20240426.002
/usr/irissys/mgr/journal/20240426.002
  2.91% 100.00%
[Journal restore completed at 20240426 15:38:32]

The following databases have been updated:

1. /usr/irissys/mgr/t1rest/

%SYS>
```

