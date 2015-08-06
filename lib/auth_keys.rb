
### ~/.auth_keys
#          softbank  080xxxxxx xxxxxxxx
#          7spot     xxxxxx@gmaol.com xxxx
#          facebook  fsfsf@example.jp xxxxxxxxx
###results 
# AuthKeysload() #=>  {
#                         "softbank"=>["08xxxxxx", "xxxxxxx"],
#                         "7spot"=>["example@gmail.com", "xxxxxxxxxxx"],
#                    }
#
#
#
#
#
#
class AuthKeys
    KEY_PATH = "~/.auth_keys"
    class << self
        def load
            path = File.expand_path(KEY_PATH)
            return unless File.exists?(path)
            array = open(path).read
            .split("\n")
            .reject{|e| e.strip =~/^#/}
            .map(&:split).map{|e| [e[0],[   e[1],e[2]  ] ] }
            password_table = Hash[array]
        end
        def get(key)
            hash = self.load
            hash.key?(key) ? hash[key] : nil ; 
        end
        def [](key)
            self.get(key)
        end
        def keys
            self.load.keys
        end
    end
end


if $0 == __FILE__ then
    require 'pp'
    pp AuthKeys["softbank"]
    pp AuthKeys.keys
    pp AuthKeys.load
end

