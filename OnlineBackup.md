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

プログラムから実行する場合は、[^DBACKルーチン](https://docs.intersystems.com/irisforhealthlatestj/csp/docbook/DocBook.UI.Page.cls?KEY=GCDI_backup#GCDI_backup_util_DBACK_entrypoints)を使用します。

以下順序で解説します。

- [1.管理ポータルのバックアップメニュー](#1管理ポータルのバックアップメニュー)
- [2.管理ポータルのタスクスケジュール](#2管理ポータルのタスクジュール)
- [3.^BACKUPルーチン](#3backupルーチン)
- [4.BACKUP^DBACKルーチン](#4backupdback)

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

    第2引数に"C"を指定します。

- 差分バックアップ

    第2引数に"I"を指定します。

## リストア方法

### システムルーチンを利用したリストア

### プログラムによるリストア