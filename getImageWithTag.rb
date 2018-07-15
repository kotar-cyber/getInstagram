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
# GETするURL
GETURL = 'https://www.instagram.com/graphql/query/?'
# 取得対象ページ
url = 'https://www.instagram.com/explore/tags/' + URI.encode_www_form_component(SEARCHTAG)
# 取得したい投稿数
GETPHOTOS = 200
# 取得した件数
gotNumber = 0

# 保存ファイル名（拡張子除く）
csvfilename = Time.now.strftime("%Y%m%d%H%M%S")

# 文字コード
charset = nil

puts SEARCHTAG + " のデータを #{GETPHOTOS} 件分取得します"

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
    if gotNumber >= GETPHOTOS then
      return gotNumber
    end
  }
  return gotNumber
end

# 2ページ以上取得する場合は次の情報を取得
def getNextPage(endCursor, csrfToken, rhx_gis)

  # variables=
  # {"tag_name":"岸和田",
  # "first":12, -> 2 -> この個数✕3個分のデータが来る（多分）
  # "after":"AQC1Nv9QzX5WgPn0RK2xuW9WQ72ZfcQGlh7WUoT7cEMkoU7j_BHT6FzWBa1EqqZ_7It1lLNj0syCdW9YUXBlG2LvVbllWDXlU4eNf6hKRZ8cMw"}
  # アクセス用URLの準備
  # URI.encode_www_form_component(SEARCHTAG)
  param = 'query_hash=ded47faa9a1aaded10161a2ff32abb6b&'
  param += 'variables='
  queryVariables = '{"tag_name":"' + URI.encode_www_form_component(SEARCHTAG) + '",'
  #queryVariables = '{"tag_name":"' + SEARCHTAG + '",'
  queryVariables += '"first":5,'
  queryVariables += '"after":"' + endCursor + '"}'
  uri = URI.parse(GETURL + param + queryVariables)
  #uri = URI.parse('https://www.google.com')
  puts "rawURL: #{GETURL + param + queryVariables}"
  #puts Digest::MD5.hexdigest('d70985bfcd443f99cbbf147e2035fffd:{"tag_name":"岸和田","first":5,"after":"AQAQnuWT08V4nGbIh4bcXj7mOMNuf-SopEIO0Vg4Ul_YNRylop04kX8ctVauN-mKf9XqBVOIUYfOs54IP2awFx_wiTnAmUwAVUSpJe-iPXfk5g"}')

  instaGIS = Digest::MD5.hexdigest('' + rhx_gis + ':{"tag_name":"' + SEARCHTAG + '","first":5,"after":"' + endCursor + '"}')
  
  puts '' + rhx_gis + ':{"tag_name":"' + SEARCHTAG + '","first":5,"after":"' + endCursor + '"}'
  puts "generated: #{instaGIS}"
  puts "csrf: #{csrfToken}"
  puts "URI:  #{uri}"
  #https = Net::HTTP.new(uri.host, uri.port)
  #https.use_ssl = true
  #req = Net::HTTP::Post.new(uri.request_uri)

  http = Net::HTTP.new(uri.host, uri.port)

  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  req = Net::HTTP::Get.new(uri.request_uri)

  req["Host"] = "www.instagram.com"
  req["X-Requested-With"] = "XMLHttpRequest"
  req["Referer"] = "https://www.instagram.com/explore/tags/"+URI.encode_www_form_component(SEARCHTAG)+"/"
  req["Cookie"] = "csrftoken="+csrfToken+";"
  #req["X-CSRFToken"] = csrfToken
  req["Connection"] = "keep-alive"
  #req["x-instagram-ajax"] = 1
  req["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
  req["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:63.0) Gecko/20100101 Firefox/63.0"
  req["X-Instagram-GIS"] = instaGIS
  
  res = http.request(req)
  p res
  puts res.body

  #pageResponse = Net::HTTP.start(uri.host, uri.port) do |http|
  #  http.request(req)
  #end

  return res.body
  #return [JSON.parse(res.body)['media']['nodes'], JSON.parse(res.body)['media']['page_info']['end_cursor']]

end

def getNextPage2(endCursor, csrfToken, rhx_gis, gotNumber)
  uri = URI.parse("https://www.instagram.com/explore/tags/" + URI.encode_www_form_component(SEARCHTAG) + "/?__a=1&max_id=" + endCursor)
  http = Net::HTTP.new(uri.host, uri.port)
  puts "access: #{uri}"

  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  req = Net::HTTP::Get.new(uri.request_uri)

  res = http.request(req)
  endCursor = JSON.parse(res.body)['graphql']['hashtag']['edge_hashtag_to_media']['page_info']['end_cursor']
  dataArray =  JSON.parse(res.body)['graphql']['hashtag']['edge_hashtag_to_media']['edges']
  
  return dataArray, endCursor
  
  #puts res.body
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
puts "endCursor: #{endCursor}"
# csvファイルにヘッダを記入
headerWrite(csvfilename)

puts "データ取得します"
puts "rhx_gis : #{rhx_gis}"

gotNumber = csvWrite(dataArray, csvfilename, gotNumber)

# 取得した件数を記録
#gotNumber = dataArray.length
puts "#{gotNumber} 件取得しました"
fetchNumber = gotNumber

# 取得件数が足りない場合は、追加で取りに行く
while GETPHOTOS > gotNumber do
  # 5秒待つ
  puts "5秒待ってから再開します"
  sleep 5
  dataArray, endCursor = getNextPage2(endCursor, csrfToken, rhx_gis, gotNumber)
  
  gotNumber = csvWrite(dataArray, csvfilename, gotNumber)# + fetchNumber
  puts "#{gotNumber} 件取得しました"
end


puts "終了しました"
