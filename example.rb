# ファイルを読み込む
require './getInstagramDataWithTag'

# 検索タグと取得件数を指定し、インスタンスを作成
instagramData = InstagramData.new(tag_name: '岸和田', get_number: 10)

# getInstagramDataメソッドでデータを取得
instagramData.getInstagramData

# 以下のプロパティにデータが入っている
instagramData.instagram_data

# writeToCSVメソッドでCSVファイルに書き出す
# 第一引数にはデータを指定する
# 第二引数を指定しなければ、
# getInstagramData_201807222200.csv
# のように現在時刻を入れたファイル名に書き出す
instagramData.writeToCSV(instagramData.instagram_data)