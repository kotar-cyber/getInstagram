require 'open-uri'
require 'nokogiri'
require 'json'
require 'net/http'
require 'net/https'
require 'uri'
require 'pp'
require 'openssl'
require 'CSV'

class InstagramData
    attr_reader :tag_name, :get_number, :instagram_data
    TAG_URL_PREFIX = 'https://www.instagram.com/explore/tags/'

    def initialize(tag_name: '岸和田', get_number: 10)
        @tag_name = tag_name
        @get_number = get_number
        @got_number = 0
    end

    def getNextPageData(endCursor, csrfToken, rhx_gis, gotNumber)
        uri = URI.parse(TAG_URL_PREFIX + URI.encode_www_form_component(@tag_name) + "/?__a=1&max_id=" + endCursor)
        http = Net::HTTP.new(uri.host, uri.port)
        
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      
        req = Net::HTTP::Get.new(uri.request_uri)
      
        res = http.request(req)
        endCursor = JSON.parse(res.body)['graphql']['hashtag']['edge_hashtag_to_media']['page_info']['end_cursor']
        dataArray =  JSON.parse(res.body)['graphql']['hashtag']['edge_hashtag_to_media']['edges']
        
        return dataArray, endCursor
    end

    def parseInstagramData(dataArray)
        dataArray.length.times do |i|
            insta_data = {userId: '', timestamp: '', pageUrl: '', likeCount: '', commentCount: '', caption: ''}
            # ユーザIDの取得
            insta_data[:userId] = dataArray[i]['node']['owner']['id']
            # UNIXタイムからの変換
            insta_data[:timestamp] = Time.at(dataArray[i]['node']['taken_at_timestamp'])
            # 画像URLの取得
            # writeData.push(dataArray[i]["thumbnail"])
            # ページURLの取得
            insta_data[:pageUrl] = "https://www.instagram.com/p/" + dataArray[i]['node']['shortcode'] + "/"
            # いいねの数とコメントの数
            insta_data[:likeCount] = dataArray[i]['node']['edge_liked_by']['count']
            insta_data[:commentCount] = dataArray[i]['node']['edge_media_to_comment']['count']
            
            # 投稿者コメントの取得
            insta_data[:caption] = (dataArray[i]['node']['edge_media_to_caption']['edges'][0]['node']['text'])

            # 投稿者コメントからタグのみ抽出
            tags = (dataArray[i]['node']['edge_media_to_caption']['edges'][0]['node']['text'] + " ").scan(/[#][Ａ-Ｚａ-ｚA-Za-z一-鿆0-9０-９ぁ-ヶｦ-ﾟー○]+/).join(" ")
            insta_data[:tags] = tags
            
            @instagram_data.push(insta_data)
            @got_number += 1
            # 予定取得枚数に到達したら終了
            break if @got_number >= @get_number
        end
    end

    def getInstagramData
        tag_search_url = TAG_URL_PREFIX + URI.encode_www_form_component(@tag_name)
        @instagram_data = []

        # 文字コード
        charset = nil

        puts "#{@tag_name} のデータを #{@get_number} 件分取得します"

        # タグ検索ページへアクセス
        # 文字コードを取得しながら、アクセス
        html = open(tag_search_url) do |f|
            charset = f.charset
            f.read
        end

        # 以下、Nokogiriによるアクセスに必要な情報の取得処理
        # 全部のHTMLを取得
        allDoc = Nokogiri::HTML.parse(html, nil, charset)
        # メタ情報だけ取得
        metaInfo = allDoc.css('body script').first.text
        # 前後に不要な情報があるのでカット
        metaInfo.slice!(0, 21)
        metaInfo = metaInfo.chop

        # 解析用JSONの保存
        response_json = JSON.parse(metaInfo)

        # データの中身を取得
        dataArray = response_json['entry_data']['TagPage'][0]['graphql']['hashtag']['edge_hashtag_to_media']['edges'];

        # 初期ページの分を取得
        parseInstagramData(dataArray)

        # 取得した件数を記録
        puts "#{@got_number} 件取得しました"

        # 取得枚数に足りていない場合
        while @got_number < @get_number do
            # 次のページの取得に必要な情報を取得
            # csrfトークンの取得
            csrfToken = response_json['config']['csrf_token']
            # rhx_gisの取得
            rhx_gis = response_json['rhx_gis']
            # 次のページ取得用のカーソル
            @endCursor = response_json['entry_data']['TagPage'][0]['graphql']['hashtag']['edge_hashtag_to_media']['page_info']['end_cursor']

            puts "5秒待ってから再開します"
            sleep 5

            dataArray, @endCursor = getNextPageData(@endCursor, csrfToken, rhx_gis, @got_number)

            parseInstagramData(dataArray)

            # 取得した件数を記録
            puts "#{@got_number} 件取得しました"
        end

    end

    # CSVファイルのヘッダを記入
    def csvHeaderWrite(csvfilename)
        CSV.open(csvfilename, "ab+") do |csv|
            writeData = Array.new
            writeData.push("ユーザID")
            writeData.push("投稿日時（日本時間）")
            writeData.push("ページURL")
            writeData.push("いいねの数")
            writeData.push("コメント数")
            writeData.push("投稿者コメント")
            writeData.push("ハッシュタグ")
        
            csv << writeData
        end
    end

    # CSVファイルへの書き込み
    def csvDataWrite(dataArray, csvfilename)
        dataArray.each do |n|
            puts "n write n is #{n}"
            CSV.open(csvfilename, "ab+") do |csv|
                # データはハッシュなので配列にし、キーを除き、値を代入する
                writeData = n.to_a.map{|e| e[1]}
                
                csv << writeData
            end
        end
    end

    # CSVファイルへの書き込み
    def writeToCSV(dataArray, csvfilename: "getInstagramData_#{Time.now.strftime("%Y%m%d%H%M%S")}.csv")
        # csvファイルにヘッダを記入
        csvHeaderWrite(csvfilename)
        # csvファイルに保存
        csvDataWrite(dataArray, csvfilename)
    end

end