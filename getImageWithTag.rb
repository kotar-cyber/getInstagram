require 'open-uri'
require 'nokogiri'
require 'json'
require 'net/http'
require 'net/https'
require 'uri'
require 'pp'
require 'openssl'
require 'CSV'
require 'digest/md5'

# 検索タグ
SEARCHTAG = '岸和田'

# 取得対象ページ
url = 'https://www.instagram.com/explore/tags/' + URI.encode_www_form_component(SEARCHTAG)
# 取得したい投稿数
GETPHOTOS = 100
# 取得した件数
gotNumber = 0

# 保存ファイル名（拡張子除く）
csvfilename = Time.now.strftime("%Y%m%d%H%M%S")

# 文字コード
charset = nil

puts SEARCHTAG + " のデータを #{GETPHOTOS} 件分取得します"


# CSVファイルのヘッダを記入
def headerWrite(csvfilename)
  CSV.open("getInstagramData_#{csvfilename}.csv", "ab+") do |csv|
    writeData = Array.new
    writeData.push("ユーザID")
    writeData.push("投稿日時（日本時間）")
    writeData.push("ページURL")
    writeData.push("いいねの数")
    writeData.push("コメント数")
    writeData.push("ハッシュタグ")
    writeData.push("投稿者コメント")
 
    csv << writeData
  end
end


# CSVファイルへの書き込み
def csvWrite(dataArray, csvfilename, gotNumber)
	dataArray.length.times {|i|
	  CSV.open("getInstagramData_#{csvfilename}.csv", "ab+") do |csv|
	    writeData = Array.new
	    # ユーザIDの取得
	    writeData.push(dataArray[i]['node']['owner']['id'])

	    # UNIXタイムからの変換
	    writeData.push(Time.at(dataArray[i]['node']['taken_at_timestamp']))

	    # 画像URLの取得
	    # writeData.push(dataArray[i]["thumbnail"])

      # ページURLの取得
      writeData.push("https://www.instagram.com/p/" + dataArray[i]['node']['shortcode'] + "/")

	    # いいねの数とコメントの数
      writeData.push(dataArray[i]['node']['edge_liked_by']['count'])
      writeData.push(dataArray[i]['node']['edge_media_to_comment']['count'])
	    
      # 投稿者コメントからタグのみ抽出
	    writeData.push((dataArray[i]['node']['edge_media_to_caption']['edges'][0]['node']['text'] + " ").scan(/[#][Ａ-Ｚａ-ｚA-Za-z一-鿆0-9０-９ぁ-ヶｦ-ﾟー○]+/).join(" "))
	    # 投稿者コメントの取得
      writeData.push("\""+dataArray[i]['node']['edge_media_to_caption']['edges'][0]['node']['text']+"\"")
      
      csv << writeData
      gotNumber += 1
    end
    # 予定取得枚数に到達したら終了
    if gotNumber >= GETPHOTOS then
      return gotNumber
    end
  }
  return gotNumber
end


def getNextPage2(endCursor, csrfToken, rhx_gis, gotNumber)
  uri = URI.parse("https://www.instagram.com/explore/tags/" + URI.encode_www_form_component(SEARCHTAG) + "/?__a=1&max_id=" + endCursor)
  http = Net::HTTP.new(uri.host, uri.port)
  
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  req = Net::HTTP::Get.new(uri.request_uri)

  res = http.request(req)
  endCursor = JSON.parse(res.body)['graphql']['hashtag']['edge_hashtag_to_media']['page_info']['end_cursor']
  dataArray =  JSON.parse(res.body)['graphql']['hashtag']['edge_hashtag_to_media']['edges']
  
  return dataArray, endCursor
end

# 文字コードを取得しつつ、ページにアクセス
html = open(url) do |f|
 charset = f.charset
 f.read
end

# 全部のHTMLを取得
allDoc = Nokogiri::HTML.parse(html, nil, charset)
# メタ情報だけ取得
metaInfo = allDoc.css('body script').first.text
# 前後に不要な情報があるのでカット
metaInfo.slice!(0, 21)
metaInfo = metaInfo.chop

# csrfトークンの取得
csrfToken = JSON.parse(metaInfo)['config']['csrf_token']

# rhx_gis
rhx_gis = JSON.parse(metaInfo)['rhx_gis']

# データの中身を取得
dataArray = JSON.parse(metaInfo)['entry_data']['TagPage'][0]['graphql']['hashtag']['edge_hashtag_to_media']['edges'];

# 次のページ取得用のカーソル
endCursor = JSON.parse(metaInfo)['entry_data']['TagPage'][0]['graphql']['hashtag']['edge_hashtag_to_media']['page_info']['end_cursor'];

# csvファイルにヘッダを記入
headerWrite(csvfilename)

puts "データ取得します"

# csvファイルに保存
gotNumber = csvWrite(dataArray, csvfilename, gotNumber)

# 取得した件数を記録
puts "#{gotNumber} 件取得しました"

# 取得件数が足りない場合は、追加で取りに行く
while GETPHOTOS > gotNumber do
  # 5秒待つ
  puts "5秒待ってから再開します"
  sleep 5
  dataArray, endCursor = getNextPage2(endCursor, csrfToken, rhx_gis, gotNumber)
  
  # 取得枚数を更新
  gotNumber = csvWrite(dataArray, csvfilename, gotNumber)
  puts "#{gotNumber} 件取得しました"
end

puts "終了しました"