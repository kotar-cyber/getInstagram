## これはなに
Instagramからタグ検索し、情報を取得するスクリプト。  
Instagram APIがひどすぎるから自作した。

検索タグと取得件数を指定したら、最新のものから順にInstagram Webページから取得する。

### 取得できる情報
- ページのURL
- 投稿日時
- コメント数
- いいね数
- 投稿者コメント
- 投稿者ID

## 使い方例（example.rbを参照）
```ruby
# ファイルを読み込む
require './getInstagramDataWithTag'

# 検索タグと取得件数を指定し、インスタンスを作成
instagramData = InstagramData.new(tag_name: '岸和田', get_number: 10)

# getInstagramDataメソッドでデータを取得
instagramData.getInstagramData

# 以下のプロパティにデータが入っている
instagramData.instagram_data
# 取得できるデータは以下
# ページのURL       instagramData.instagram_data[0][:pageUrl]
# 投稿日時          instagramData.instagram_data[0][:timestamp]
# コメント数        instagramData.instagram_data[0][:commentCount]
# いいね数          instagramData.instagram_data[0][:likeCount]
# 投稿者コメント    instagramData.instagram_data[0][:caption]
# 投稿者ID          instagramData.instagram_data[0][:userId]

# writeToCSVメソッドでCSVファイルに書き出す
# 第一引数にはデータを指定する
# 第二引数を指定しなければ、
# getInstagramData_201807222200.csv
# のように現在時刻を入れたファイル名に書き出す
instagramData.writeToCSV(instagramData.instagram_data)
```