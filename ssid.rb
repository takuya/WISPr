#!/usr/bin/env ruby
#coding: utf-8
#

require 'openssl'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
I_KNOW_THAT_OPENSSL_VERIFY_PEER_EQUALS_VERIFY_NONE_IS_WRONG=true

require 'mechanize'



class WisprLogin
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
        self.chech_local_ip
        ret = self.check_captive_network



        case ssid

        when /softbank/i
            softbank_login( *@@passwords["softbank"]  )

        when /mobilepoint/i
            mobilepoint_login( *@@passwords["mobilepoint"]  )
        when /starbucks/i
            starbucks_login( *@@passwords["starbucks"]  )
        when /au/i
            #`open -a "au Wi-Fi接続ツール"`
            auWifi_login( *@@passwords["au"]  )
        when /wi2/i
            login( *@@passwords["wi2"]  )
        when /7spot/i
            login_7spot( *@@passwords["7spot"]  )
        when /turllys/i
            turllys_login()
        when /wifihhdept/
            login( *@passwords["wifihhdept"] )
        end


    end

    def chech_local_ip
        case RUBY_PLATFORM
        when /darwin/i
            unless `ifconfig en0  | grep -e "inet " | grep -v 169 `.strip.size>0 then
                sleep 0.5
            end

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
    def login( user, pass)

        return unless self.check_captive_network


        forms =  m.page.forms.select{|e| e.fields_with(:type=>"password").size == 1 and ( e.fields_with(:type=> "text" ).size > 0  or e.fields_with(:type=> nil ).size > 0 ) }


        raise "ログインフォーム見つからない" unless forms.size > 0

        f = m.page.forms[0]
        f.field_with(:type=>/tex/i).value = user
        f.field_with(:type=>/pass/i).value = pass
        f.submit

        m.page.body

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
    def login_7spot(user,pass)

        return unless self.check_captive_network
        ##専用ログインURL
        m.get("http://webapp-ap.7spot.jp/banners/click/4395?tmst=1437268072")


        forms =  m.page.forms.select{|e| e.fields_with(:type=>"password").size == 1 and ( e.fields_with(:type=> "text" ).size > 0  or e.fields_with(:type=> "text" ).size > 0 ) }
        raise "ログインフォーム見つからない" unless forms.size > 0

        form = forms.first
        form.field_with( :type=>"password").value = pass
        form.fields_with( :type=>"text").first.value = user
        p form
        form.submit

        m.page.body
    end
    def auWifi_login(id,pw)


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

    $: <<  File.dirname(File.realpath(__FILE__))+ "/lib"
    require 'auth_keys'

    wispr = WisprLogin.new(AuthKeys.load)
    wispr.start_wispr


end
