require 'open-uri'
require 'nokogiri'
require 'json'

# 取得対象ページ
url = 'https://www.instagram.com/explore/tags/snow/'

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
p JSON.parse(metaInfo)['config']['csrf_token']
#p metaInfo.chop
