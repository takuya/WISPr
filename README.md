## 公衆無線LANに自動ログインするための設定

mac の launchctl で自動ログインをを実現する。
```
launchctl load biz.takuya.wispr.plist # インストール例
```

## 依存モジュール

ruby mechanize

## 依存モジュールのインストール方法

```
sudo su -l
gem install mechanize
```


## 自動起動の設定。

```
cp ssid_agent.xml ~/Library/LaunchAgents/biz.takuya.wispr.plist
cd ~/Library/LaunchAgents/biz.takuya.wispr.plist
launchctl load biz.takuya.wispr.plist
```

xmlを ~/Library/LaunchAgentsにコピー、ファイル名は任意です。 

## 自動機能のログイン機能

ssid.rb の ユーザー名とパスワードを書き換えます。

ファイルを/usr/local/binに置きます。

```
sudo cp ssid.rb /usr/local/bin/ssid.rb
sudo chmod a+x /usr/local/bin/ssid.rb
```


/usr/local/bin 以外に置く場合は ssid_agent.xmlで指定されてるPathも変更してください。

## テスト

rubyファイルの起動＆動作チェックは直接起動すれば出来ます。  

```
sudo /usr/local/bin/ssid.rb
```

