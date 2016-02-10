require 'open-uri'
require 'nokogiri'
require 'json'
require 'net/http'
require 'uri'
require 'pp'

# 検索タグ
SEARCHTAG = 'snow'
# POSTするURL
POSTURL = 'https://www.instagram.com/query/'
# 取得対象ページ
url = 'https://www.instagram.com/explore/tags/' + SEARCHTAG

charset = nil

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
#p csrf_token
#p JSON.parse(metaInfo)
#p JSON.parse(metaInfo)['entry_data']['TagPage'][0]['tag']['media']['page_info']['end_cursor']
end_cursor = JSON.parse(metaInfo)['entry_data']['TagPage'][0]['tag']['media']['page_info']['end_cursor']
start_cursor = JSON.parse(metaInfo)['entry_data']['TagPage'][0]['tag']['media']['page_info']['start_cursor']
#p JSON.parse(metaInfo)['entry_data']['TagPage'][0]['tag']['media']['nodes'].length

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
req.body = "q=ig_hashtag(#{SEARCHTAG})+%7B+media.after(#{start_cursor}%2C+12)+%7B%0A++count%2C%0A++nodes+%7B%0A++++caption%2C%0A++++code%2C%0A++++location+%7B%0A++++++id%2C%0A++++++lat%2C%0A++++++lng%0A++++%7D%2C%0A++++comments+%7B%0A++++++count%0A++++%7D%2C%0A++++date%2C%0A++++dimensions+%7B%0A++++++height%2C%0A++++++width%0A++++%7D%2C%0A++++display_src%2C%0A++++id%2C%0A++++is_video%2C%0A++++likes+%7B%0A++++++count%0A++++%7D%2C%0A++++owner+%7B%0A++++++id%0A++++%7D%2C%0A++++thumbnail_src%0A++%7D%2C%0A++page_info%0A%7D%0A+%7D&ref=tags%3A%3Ashow'"
res = https.request(req)
puts "code -> #{res.code}"
puts "mes -> #{res.message}"
puts "body -> #{res.body}"
puts "cursor -> #{JSON.parse(res.body)['media']['page_info']['end_cursor']}"

# '' -H 'Host: www.instagram.com'
# --compressed
#  -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8'
# -H 'X-Instagram-AJAX: 1'
# -H 'X-CSRFToken: a418dd90657c98861f2bb663a1f12726'
# -H 'X-Requested-With: XMLHttpRequest'
# -H 'Referer: https://www.instagram.com/explore/tags/snow/'
# -H 'Cookie: csrftoken=a418dd90657c98861f2bb663a1f12726;'
# -H 'Connection: keep-alive'
# --data 'q=ig_hashtag(snow)+%7B+media.after(1176870845065662487%2C+12)+%7B%0A++count%2C%0A++nodes+%7B%0A++++caption%2C%0A++++code%2C%0A++++location+%7B%0A++++++id%2C%0A++++++lat%2C%0A++++++lng%0A++++%7D%2C%0A++++comments+%7B%0A++++++count%0A++++%7D%2C%0A++++date%2C%0A++++dimensions+%7B%0A++++++height%2C%0A++++++width%0A++++%7D%2C%0A++++display_src%2C%0A++++id%2C%0A++++is_video%2C%0A++++likes+%7B%0A++++++count%0A++++%7D%2C%0A++++owner+%7B%0A++++++id%0A++++%7D%2C%0A++++thumbnail_src%0A++%7D%2C%0A++page_info%0A%7D%0A+%7D&ref=tags%3A%3Ashow'

#p metaInfo.chop
