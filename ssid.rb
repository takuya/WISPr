#!/usr/bin/env ruby
#coding: utf-8
#

require 'pry'
require 'openssl'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
I_KNOW_THAT_OPENSSL_VERIFY_PEER_EQUALS_VERIFY_NONE_IS_WRONG=true

require 'mechanize'
require 'pry'



class WisprLogin
    class ::Hash
      alias_method :original_get_value , :[]
      def [](*args)
        if args[0].class == ::Regexp then
          found = self.find{|k,v| k=~ args[0] }
          key = found[0]
          self.original_get_value(key)
        else
          self.original_get_value(*args)
        end
      end

    end
    attr_accessor :m
    def initialize(passwords)
        @m = Mechanize.new
        @@passwords = passwords
    end

    def current_ssid
      case RUBY_PLATFORM
      when /darwin/i
          ret = `/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport -I | /usr/bin/grep -ie '^\s*ssid'  | cut -d ":" -f 2`
          ret.strip!
          return ret
      end
      return nil
    end


    def start_wispr
        ssid = self.current_ssid
        self.check_local_ip
        # ret = self.check_captive_network
        # puts  ssid

        case ssid

        when /softbank/i
            softbank_login( *@@passwords["softbank"]  )

        when /mobilepoint/i
            mobilepoint_login( *@@passwords["mobilepoint"]  )
        when /starbucks/i
            starbucks_login( *@@passwords["starbucks"]  )
        when /au/i
            auWifi_login( *@@passwords["au"]  )
        when /wi2/i
            wi2_login( *@@passwords[/wi2/]  )
        when /7spot/i
            login_7spot( *@@passwords[/7spot/]  )
        when /turllys/i
            turllys_login()
        when /wifihhdept/
            login( *@@passwords[/wifihhdept/] )
        when /docomo/i
            login( *@@passwords[/docomo/]  )
        end


    end

    def check_local_ip
        case RUBY_PLATFORM
        when /darwin/i
            10.times{
                unless ip = `( ipconfig getifaddr en0 || ipconfig getifaddr en3)   | grep -v 169 `.strip.size>0 then 
                    Thread.pass
                    sleep 0.5 
                else 
                    return ip 
                end
            }
            #raise "No IP address obtained."
        end
    end

    def check_captive_network
        cnt = 1
        begin
          m.get 'http://www.apple.com/library/test/success.html'
        rescue => e
            sleep 1 # waitting DNS
            cnt = cnt + 1 
            retry if cnt < 10
        end
        return m.page.search("//body/text()").text != "Success"
    end

    def start_au_wifi_tool
      `open -a "au Wi-Fi接続ツール"`
    end
    def stop_au_wifi_tool
      # au wifi の起動しっぱなしは面倒だから消します。
      # puts `pgrep au\ Wifi`
      puts "au Wifiツール殺す"
         `pkill  au\\ Wi-Fi ` if `pgrep au\\ Wi-Fi`
    end
    def login( user, pass,force=false)


        return unless force ||  self.check_captive_network

        forms =  m.page.forms.select{|e| e.fields_with(:type=>"password").size == 1 and ( e.fields_with(:type=> "text" ).size > 0  or e.fields_with(:type=> nil ).size > 0 ) }


        raise "ログインフォーム見つからない" unless forms.size > 0

        f = m.page.forms[0]
        f.field_with(:type=>/tex/i).value = user
        f.field_with(:type=>/pass/i).value = pass
        f.submit

        print m.page.body

    end

    def wi2_login(user,pass)
        self.login(user,pass)
    end
    def starbucks_login(user,pass)

      return unless  self.check_captive_network

      ## Starbucks に一度ログインしてたら、暫くの間は、MACアドレスから認証すっとばせる
      unless  m.page.forms[0].button_with(:name => /yes/i) then 
          self.login(user,pass)
      else
          m.page.forms[0].submit
      end


    end
    def mobilepoint_login(user,pass)

        ## UA 制限
        m.user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 8_0 like Mac OS X) AppleWebKit/600.1.3 (KHTML, like Gecko) Version/8.0 Mobile/12A4345d Safari/600.1.4"

        self.check_captive_network

        forms =  m.page.forms.select{|e| e.fields_with(:type=>"password").size == 1 and ( e.fields_with(:type=> "text" ).size > 0  or e.fields_with(:type=> nil ).size > 0 ) }
        raise "ログインフォーム見つからない" unless forms.size > 0

        form = forms.first
        form.field_with( :type=>"password").value = pass
        form.fields_with( :name => /user/i ).first.value = user.split(/@/).first
        form.fields_with( :name => /suffix/i ).first.value = user.split(/@/).last
        p form
        form.submit

        print m.page.body.toutf8
    end
    def reset_to_dhcp
        #`/usr/sbin/networksetup -setdhcp Wi-Fi`
    end
    def login_7spot(user,pass,omini7=false)
      # 7 Soot はWiSPrも、CaptiveNetworkも無視してくる
        m.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_1) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36"
        ## リダイレクト画面でCookieを貰う。
        ##    JSチェックが　cookiecheck=true になるので代替
        m.get "http://redir.7spot.jp/redir/"
        host = m.page.uri.host
        cookie = Mechanize::Cookie.new(
                  'cookiecheck', host, {
                      :value=>"true",
                      :domain=>host,
                      :path=>"/",
                      :expires=>Time.now+60*60*24
                })
        m.cookie_jar.add(cookie)
        ## タイムスタンプでチェックしてるのでCookieを付けて送信
        m.get "http://webapp-ap.7spot.jp/?tmst="+(Time.now().to_i/1000).to_s
        ## 再びCookieが消される可能性があるので対応
        m.cookie_jar.add(cookie)

        ## ログイン画面を探す
        a = m.page.search("//a[@href][.//img[@src='http://core.7spot.jp/imgs/7/k46e3.png']] ")[0]
        m.get a.attr("href")

        ## オムニ７会員の設定が追加されたので対応
        f = m.page.search("input[value^='7SPOT']") unless omini7
        f = m.page.search("input[value^='オムニ']") if omini7
        match = f.attr("onclick").value.match(/location.href='(.+)'/)
        href = match[1]
        m.get href
        ## 再びCookieが消される可能性があるので対応
        m.cookie_jar.add(cookie)

        ## ログイン実行する。
        self.login(user,pass,force=true)
        ## 7spot はCaptiveNetworkの仕様ガン無視して、セブンに都合のいいfilteringをしているので注意
        ## ログイン後に「利用規約の同意」が必要だった。
        m.get "/internet" 
        if m.page.body.to_s.toutf8 =~ /利用規約に同意し/
          m.get "/internet/auth/?p" + Time.now.to_s
          keys = m.page.body
          keys = JSON.load(keys)
          m.history.pop
          f = m.page.forms[0]
          f.field_with(:name=>/user/).value =  keys["login_identity"]
          f.field_with(:name=>/pass/).value =  keys["password"]
          f.submit
        end

        print m.page.body
        

    end
    def auWifi_login(id,pw)

        #`open -a "au Wi-Fi接続ツール"`

        return unless self.check_captive_network

        ##専用ログインURL
        ## parse host
        a = m.page.uri.to_s
        b = m.page.uri.path || ""
        c = m.page.uri.query || ""


        unless a=~/wi2/i then 
            ## POST to /smartlogin
            d = a.gsub(b+"?"+c ,"")
            x = d+"/smartlogin"

            m.post x, {UserName: id ,Password: pw }


            body = m.page.body.toutf8
            match =  body.match(/(\/login\?cid=[^&]+&username=[0-9a-zA-Z]+)/) 
            raise unless match

            y = d +  match[1]

            m.get y
        else
            # au-Wifi で wi2 が飛んでる箇所がある
            s = m.page.search("//head").to_s.lines.grep(/<Login/)
            s[0] =~ /<LoginURL>([^<]*)<\/LoginURL>/
            x = $1
            m.post x, {UserName: id ,Password: pw }
            return 

        end


    end

    def softbank_login(id,pw)

        require 'mechanize'

        m.user_agent = "SoftBank/2.0/004SH/SHJ001/SN 12345678901 Browser/NetFront/3.5 Profile/MIDP-2.0 Configuration/CLDC-1.1"
        return unless self.check_captive_network
        #m.get "https://plogin1.pub.w-lan.jp/wrs?i=074&v=100"

        f = m.page.form_with(:action => /wrslogin/ )
        f.field_with(:name=>/SWSUserName/).value=id
        f.field_with(:name=>/SWSPassword/).value=pw
        btn = f.button_with(:type=>/submit/i)



        m.submit(f,btn)
        #print m.page.body.toutf8

    end

    def turllys_login()

        return if check_captive_network
        m.page.forms[0].submit
        m.page.forms[0].submit

    end
end





if __FILE__ == $0 then 

    require 'pp'

    require 'auth_keys'

    wispr = WisprLogin.new(AuthKeys.load)
    wispr.start_wispr


end
