require 'open-uri'
require 'nokogiri'
require 'json'
require 'net/http'
require 'uri'
require 'pp'
require 'openssl'
require 'CSV'

# 検索タグ
SEARCHTAG = '岸和田'
# POSTするURL
POSTURL = 'https://www.instagram.com/query/'
# 取得対象ページ
url = 'https://www.instagram.com/explore/tags/' + URI.encode_www_form_component(SEARCHTAG)
# 取得ページ数（1ページに12データ）
GETPAGES = 10

# 保存ファイル名（拡張子除く）
csvfilename = Time.now.strftime("%Y%m%d%H%M%S")

# 文字コード
charset = nil

puts SEARCHTAG + " のデータを #{GETPAGES} 件取得します"

# JSONデータを配列に格納する
def parseInstagramJson(jsondata)
 returnData = []
 jsondata.length.times { |i|
   oneData = {}
   oneData["code"] = jsondata[i]["code"]
   oneData["date"] = jsondata[i]["date"]
   oneData["comments"] = jsondata[i]["comments"]
   oneData["caption"] = jsondata[i]["caption"]
   oneData["likes"] = jsondata[i]["likes"]
   oneData["owner"] = jsondata[i]["owner"]
   oneData["thumbnail"] = jsondata[i]["thumbnail_src"]
   oneData["is_video"] = jsondata[i]["is_video"]
   oneData["id"] = jsondata[i]["id"]
   oneData["location"] = jsondata[i]["location"]

   returnData.push(oneData)
 }
 return returnData
end

# CSVファイルのヘッダを記入
def headerWrite(csvfilename)
 CSV.open("getInstagramData_#{csvfilename}.csv", "ab+") do |csv|
   writeData = Array.new
   writeData.push("ユーザID")
   writeData.push("ユーザ名")
   writeData.push("投稿日時（日本時間）")
   writeData.push("ページURL")
   writeData.push("いいねの数")
   writeData.push("コメント数")
   writeData.push("緯度（あれば）")
   writeData.push("経度（あれば）")
   writeData.push("場所のID（あれば）")
   writeData.push("ハッシュタグ")
   writeData.push("投稿者コメント")
   writeData.push("リアクションコメント")

   csv << writeData
 end
end

# ユーザのコメントを表示
# 複数件ある場合は改行で区切る
def getUserComments(url)
  charset = nil

  commentsArray = Array.new

  # 文字コードを取得しつつ、ページにアクセス
  html = open(url) do |f|
    charset = f.charset
    f.read
  end

  # 全部のHTMLを取得
  allDoc = Nokogiri::HTML.parse(html, nil, charset)
  # メタ情報だけ取得
  metaInfo = allDoc.css('script')[6].text
  # 前後に不要な情報があるのでカット
  metaInfo.slice!(0, 21)
  metaInfo = metaInfo.chop

  metaInfo = JSON.load(metaInfo)

  # コメント数の取得
  commentsCount = metaInfo['entry_data']['PostPage'][0]['media']['comments']['count']

  commentsCount.times {|i|
    commentText = metaInfo['entry_data']['PostPage'][0]['media']['comments']['nodes'][i]['text']
    strText = commentText.gsub(/\\u([\da-fA-F]{4})/) { [$1].pack('H*').unpack('n*').pack('U*') }
    commentsArray.push(strText)
  }

  return commentsArray.join("\r\n")
end

# CSVファイルへの書き込み
def csvWrite(dataArray, csvfilename)

	dataArray.length.times {|i|
	  CSV.open("getInstagramData_#{csvfilename}.csv", "ab+") do |csv|
	    writeData = Array.new
	    # ユーザ情報の取得（フルネームは無い場合がある）
	    writeData.push(dataArray[i]["owner"]["username"])
	    if dataArray[i]["owner"]["full_name"]
	      writeData.push("\""+dataArray[i]["owner"]["full_name"]+"\"")
	    else
	      writeData.push("")
	    end

	    # UNIXタイムからの変換
	    writeData.push(Time.at(dataArray[i]["date"]))

	    # 画像URLの取得
	    # writeData.push(dataArray[i]["thumbnail"])

      # ページURLの取得
      writeData.push("https://www.instagram.com/p/" + dataArray[i]["code"] + "/")


	    # いいねの数とコメントの数
	    writeData.push(dataArray[i]["likes"]["count"])
	    writeData.push(dataArray[i]["comments"]["count"])


	    # 位置情報の取得（位置情報は無い場合がある）
	    if dataArray[i]["location"]
	      writeData.push(dataArray[i]["location"]["lat"]) if dataArray[i]["location"]["lat"]
	      writeData.push(dataArray[i]["location"]["lng"]) if dataArray[i]["location"]["lng"]
	      writeData.push(dataArray[i]["location"]["id"]) if dataArray[i]["location"]["id"]
	    else
	      3.times {
	        writeData.push("")
	      }
	    end


      # 投稿者コメントからタグのみ抽出
	    writeData.push((dataArray[i]["caption"] + " ").scan(/[#][Ａ-Ｚａ-ｚA-Za-z一-鿆0-9０-９ぁ-ヶｦ-ﾟー○]+/).join(" "))
	    # 投稿者コメントの取得
	    writeData.push("\""+dataArray[i]["caption"]+"\"")

	    # リアクションコメントがある場合は取得する
	    if dataArray[i]["comments"]["count"] != 0
	      pageUrl = 'https://www.instagram.com/p/' + dataArray[i]["code"]
	      userComments = getUserComments(pageUrl)
	      writeData.push(userComments)
	    end

	    csv << writeData
	  end
	}
end

# 2ページ以上取得する場合は次の情報を取得
def getNextPage(start_cursor, csrf_token)
  # postの準備
  uri = URI.parse(POSTURL)
  https = Net::HTTP.new(uri.host, uri.port)

  https.use_ssl = true

  req = Net::HTTP::Post.new(uri.request_uri)
  # ヘッダの作成
  req["Host"] = "www.instagram.com"
  req["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
  req["X-Instagram-AJAX"] = 1
  req["X-CSRFToken"] = csrf_token
  req["X-Requested-With"] = "XMLHttpRequest"
  req["Referer"] = "https://www.instagram.com/explore/tags/"+SEARCHTAG+"/"
  req["Cookie"] = "csrftoken="+csrf_token+";"
  req["Connection"] = "keep-alive"


  # POSTデータの作成
  req.body = "q=ig_hashtag(#{SEARCHTAG})+%7B+media.after(#{start_cursor}%2C+12)+%7B%0A++count%2C%0A++nodes+%7B%0A++++caption%2C%0A++++code%2C%0A++++location+%7B%0A++++++id%2C%0A++++++lat%2C%0A++++++lng%0A++++%7D%2C%0A++++comments+%7B%0A++++++count%0A++++%7D%2C%0A++++date%2C%0A++++dimensions+%7B%0A++++++height%2C%0A++++++width%0A++++%7D%2C%0A++++display_src%2C%0A++++id%2C%0A++++is_video%2C%0A++++likes+%7B%0A++++++count%0A++++%7D%2C%0A++++owner+%7B%0A++++++id%2C%0A++++++username%2C%0A++++++full_name%0A++++%7D%2C%0A++++thumbnail_src%0A++%7D%2C%0A++page_info%0A%7D%0A+%7D&ref=tags%3A%3Ashow'"
  res = https.request(req)
  puts "mes -> #{res.message}"

  return [JSON.parse(res.body)['media']['nodes'], JSON.parse(res.body)['media']['page_info']['end_cursor']]

end

# 文字コードを取得しつつ、ページにアクセス
html = open(url) do |f|
 charset = f.charset
 f.read
end

# 全部のHTMLを取得
allDoc = Nokogiri::HTML.parse(html, nil, charset)
# メタ情報だけ取得
metaInfo = allDoc.css('script')[6].text
# 前後に不要な情報があるのでカット
metaInfo.slice!(0, 21)
metaInfo = metaInfo.chop
# csrfトークンの取得
csrf_token = JSON.parse(metaInfo)['config']['csrf_token']

#end_cursor = JSON.parse(metaInfo)['entry_data']['TagPage'][0]['tag']['media']['page_info']['end_cursor']
start_cursor = JSON.parse(metaInfo)['entry_data']['TagPage'][0]['tag']['media']['page_info']['start_cursor']
getDataLength = JSON.parse(metaInfo)['entry_data']['TagPage'][0]['tag']['media']['nodes'].length

dataArray = parseInstagramJson(JSON.parse(metaInfo)['entry_data']['TagPage'][0]['tag']['media']['nodes'])

headerWrite(csvfilename)

# 取得回数分取得
GETPAGES.times { |i|
 puts "データ取得 #{i+1} / #{GETPAGES}"
 returnData = getNextPage(start_cursor, csrf_token)

 dataArray = parseInstagramJson(returnData[0])
 csvWrite(dataArray, csvfilename)

 start_cursor = returnData[1]

 sleep 5

}

puts "終了しました"
