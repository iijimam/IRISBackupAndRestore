Class ZRestore.Journal
{

ClassMethod RedirectTest() As %Status
{
    #dim ex As %Exception.AbstractException
    set status=$$$OK
    try {
        #;ジャーナルリストア用インスタンス生成
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
        $$$ThrowOnError(jrnrest.SelectUpdates(source))
        #; リダイレクト先の指定 
        $$$ThrowOnError(jrnrest.RedirectDatabase(source,target))

        #; ジャーナルの整合性チェック
	    set status=jrnrest.CheckJournalIntegrity(1) 

        #; リストア実行
        $$$ThrowOnError(jrnrest.Run())
    }
    catch ex {
        set status=ex.AsStatus()
    }
    return status
}

}
