ルート探索コンバーター
--------------------------------

■ 何?

自転車でツーリングするときに XX km 先の YY の交差点を右折... といった指示書きを
簡単に生成できるようにするためのツールです。

ルートは Google Map (旧版) で作成し、さらに細かい指示を加えるような流れになります。

■ 構成

ルート探索コンバーターは2種類のツールで構成されます。
1つは、Google Map (旧版) のルート探索の URL からプロフィールマップと大ざっぱなルート指示書を生成する部分です。
もう1つは、ルート指示書から自転車に固定して使用する A5 PDF ファイルを生成する部分です。

前者は plot、後者を topdf と呼んでいます。

■ plot : Google Map (旧版) のルート探索の URL からプロフィールマップと大ざっぱなルート指示書を生成

plot を使用するには以下のツールが必要です。

・Ruby バージョン 1.9 以降
・GNUPLOT

次のような形式の URL リスト ファイルから生成します。
"PC(番号)": は決めうちになっています。
番号順にルートが作成されます。

-- ここから --
"PC1":https://maps.google.co.jp/maps?saddr=%E5%9B%BD%E9%81%93372%E5%8F%B7%E7%B7%9A&daddr=34.9839281,135.0618293+to:34.976053,135.0580181+to:34.9512081,135.0271608+to:34.9086497,134.9656441+to:34.8773833,134.8727323+to:34.8718167,134.8424114+to:34.8707165,134.8403377+to:34.8380581,134.733855+to:%E5%9B%BD%E9%81%93372%E5%8F%B7%E7%B7%9A+to:%E7%9C%8C%E9%81%93219%E5%8F%B7%E7%B7%9A+to:%E5%9B%BD%E9%81%932%E5%8F%B7%E7%B7%9A+to:%E6%8C%87%E5%AE%9A%E3%81%AE%E5%9C%B0%E7%82%B9+to:34.828913,134.44316+to:34.8305621,134.405615+to:%E5%9B%BD%E9%81%932%E5%8F%B7%E7%B7%9A&hl=ja&ie=UTF8&ll=34.79125,134.584579&spn=0.523859,1.056747&sll=34.831022,134.553713&sspn=0.008181,0.016512&geocode=FZsmFgIdhqINCA%3BFfjPFQIdReEMCCkJqINujnQAYDFBwznpW_7sxw%3BFTWxFQIdYtIMCCkfH86qi3QAYDFzEK2F4lFf8w%3BFShQFQId2FkMCCkPSkO0unUAYDEN6qbbvDz7zg%3BFempFAIdjGkLCClpokISCzNVNTGo6-rRvTrPSw%3BFccvFAIdnP4JCCkP7-0TvC9VNTF--pu0cJD0Hg%3BFQgaFAIdK4gJCCm9-N8ThSVVNTExOlx_j7Ah0A%3BFbwVFAIdEYAJCCl_yQAWkCVVNTH0pVLbgOGtug%3BFSqWEwIdH-AHCCkTMwFPYSBVNTFAgT8GOKZlkQ%3BFaWZEwIdeWcHCA%3BFb5tEwId_VYHCA%3BFYKIEwIdxSYGCA%3BFQyAEwIdwx4FCA%3BFXFyEwIdmHADCClxLFu-zvlUNTFL-82WCyXesw%3BFeJ4EwId790CCCmZ_oAO-fdUNTEhMLFEm-ygoQ%3BFUVwEwIdcYwCCA&dirflg=w&brcurrent=3,0x3554e4ad0f9d7dc3:0x106dbdd4660d7f6e,0&mra=dme&mrsp=12&sz=17&via=1,2,3,4,5,6,7,8,13,14&t=m&z=11

"PC2":https://maps.google.co.jp/maps?saddr=%E5%9B%BD%E9%81%932%E5%8F%B7%E7%B7%9A&daddr=%E7%9C%8C%E9%81%9354%E5%8F%B7%E7%B7%9A+to:%E7%9C%8C%E9%81%9354%E5%8F%B7%E7%B7%9A+to:34.485449,133.334194+to:%E5%9B%BD%E9%81%932%E5%8F%B7%E7%B7%9A+to:%E7%9C%8C%E9%81%933%E5%8F%B7%E7%B7%9A+to:34.4660365,133.4877412+to:%E6%8C%87%E5%AE%9A%E3%81%AE%E5%9C%B0%E7%82%B9+to:%E6%8C%87%E5%AE%9A%E3%81%AE%E5%9C%B0%E7%82%B9+to:%E5%9B%BD%E9%81%932%E5%8F%B7%E7%B7%9A+to:34.4621011,133.5435036+to:34.5003461,133.6251528+to:34.508984,133.647935+to:%E7%9C%8C%E9%81%9347%E5%8F%B7%E7%B7%9A+to:%E7%9C%8C%E9%81%9347%E5%8F%B7%E7%B7%9A+to:%E6%8C%87%E5%AE%9A%E3%81%AE%E5%9C%B0%E7%82%B9+to:%E6%B0%B4%E7%8E%89%E3%83%96%E3%83%AA%E3%83%83%E3%82%B8%E3%83%A9%E3%82%A4%E3%83%B3%2F%E7%9C%8C%E9%81%93398%E5%8F%B7%E7%B7%9A&hl=ja&ie=UTF8&ll=34.488448,133.522339&spn=0.262888,0.528374&sll=34.485512,133.4411&sspn=0.016431,0.033023&geocode=FYo-DQIdXObwBw%3BFcHNDQIdK6bxBw%3BFSgFDgIdLSzyBw%3BFck0DgIdsoTyBykdSKx3eRBRNTHb_cxavBuolw%3BFW46DgIdARbzBw%3BFRBCDgId8hr0Bw%3BFfToDQIdfdz0Bymtpu80UmtRNTFLr8CbboXRrw%3BFTMfDgIdSET1Bw%3BFdUWDgIdqk71Bw%3BFawoDgId5X31Bw%3BFZXZDQIdT7b1BynrWNXpx2tRNTEXp6DsdOy_lg%3BFfpuDgIdQPX2BylPp5FM20JRNTE4nNB8k2JsgA%3BFbiQDgIdP073BymXKcWSxVxRNTGHdSHqSjgc3A%3BFX2oDgIdR0f3Bw%3BFUevDgIdqFf3Bw%3BFVzXDgId8EL3Bw%3BFUgKDwIdv0L4Bw&dirflg=w&brcurrent=3,0x35511463c7875125:0xd8f6bde5d7736915,0&mra=dme&mrsp=5&sz=16&via=3,6,10,11,12&t=m&z=12
-- ここまで --

生成されるファイルは次のものになります。

・PC(番号).png       : プロフィールマップ
・route_template.txt : ルート指示書き
・route.gpx          : 高度情報付きの全ルート

■ topdf : ルート指示書から自転車に固定して使用する A5 PDF ファイルを生成

・Ruby バージョン 1.9 以降
・Calibre バージョン 2 以降 

次のような形式のルート指示書から PDF を生成します。

-- ここから --
いつものルート
@E:R1, W:R1/R9 | E -> W | 
+0.01h

@NW:R9, W:R372, E:K403, SE:R9 | SE -> W | 加塚
+25.5km

-- PC1 --
-- ここまで --

PC(番号).png があれば各ページに表示します。

@ の前の行はコメント
@ の行は各方位と道名、進行方向、交差点名
+ の行は距離 (km) または時間 (h) の経過数。

■ セットアップ

setup.bat を設定し、作成したファイルを plot.bat や topdf.bat に食わせてください。
