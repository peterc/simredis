require 'rubygems'
require 'redis'

class Redis
  class Emulator
    PREFIX = {
      :error => "-",
      :status => "+",
      :integer => ":",
      :bulk => "$",
      :multi_bulk => "*"
    }
    
    STATUS = lambda { |m| [PREFIX[:status], m.to_s] }
    ERROR = lambda { |m| [PREFIX[:error], m.to_s] }
    BULK = lambda { |m|
      if m
        [PREFIX[:bulk], m.to_s.length.to_s, m.to_s]
      else
        [PREFIX[:bulk], -1]
      end
    }
    INTEGER = lambda { |m| [PREFIX[:integer], m.to_i] }
    MULTI_BULK = lambda { |m|
      response = [PREFIX[:multi_bulk], m.length.to_s]
      m.each do |m1|
        if m1
          response += [PREFIX[:bulk], m1.to_s.length.to_s, m1.to_s, "\r\n"]
        else
          response += [PREFIX[:bulk], -1]
        end
      end
      response
    }
    
    def initialize
      flushall
      select([0])
    end
    
    # ---- CONNECTION HANDLING COMMANDS
    
    # http://code.google.com/p/redis/wiki/QuitCommand
    def quit(args, data); end

    # http://code.google.com/p/redis/wiki/AuthCommand
    def auth(args, data)
      # TODO: Actually do authentication. Ignore for now.
      STATUS[:OK]
    end
    
    # ---- GENERIC COMMANDS
    
    def exists(args)
      [PREFIX[:integer], @data[args.first] ? "1" : "0"]
    end
    
    # http://code.google.com/p/redis/wiki/DelCommand
    def del(args)
      removed = 0
      args.each do |arg|
        removed += 1 if @data[arg]
        @data.delete(arg)
      end
      
      INTEGER[removed]
    end   
    
    def type(args)
      return STATUS[:none] unless @data[args.first]
      return STATUS[:string] if String === @data[args.first]
      return STATUS[:list] if Array === @data[args.first]
      return STATUS[:set] if Set === @data[args.first]
      return STATUS[:zset] if SortedSet === @data[args.first]
      return STATUS[:hash] if Hash === @data[args.first]
    end
    
    def keys(args)
      regex = args.first.gsub('?', '.').gsub('*', '.*')
      MULTI_BULK[@data.keys.select { |k| k =~ /#{regex}/ }]
    end
    
    def randomkey(args)
      STATUS[@data.keys[rand(@data.size)]]
    end
    
    def rename(args)
      from, to = args
      @data[to] = @data[from]
      @data.delete(from)
      STATUS[:OK]
    end

    def renamenx(args)
      from, to = args
      return INTEGER[0] if @data[to]
      rename(args)
      INTEGER[1]
    end
    
    def dbsize(args)
      INTEGER[@data.size]
    end
    
    # TODO: Implement!
    def expire(args)
    end
    
    # TODO: Implement!
    def ttl(args)
    end
    
    def select(args = nil, data = nil)
      @current_db = args.first.to_i
      @data = @datasets[@current_db]
      STATUS[:OK]
    end
    
    def move(args)
      key, dbindex = args
      return INTEGER[0] if !@data[key]
      return INTEGER[0] if @datasets[dbindex.to_i][key]
      @datasets[dbindex.to_i][key] = @data[key]
      @data.delete(key)
      INTEGER[1]
    end
    
    def flushdb(args = nil, data = nil)
      @data = {}
      STATUS[:OK]
    end
    
    def flushall(args = nil, data = nil)
      @datasets = Array.new(32).map { |el| Hash.new }
      @data = @datasets[@current_db || 0]
      STATUS[:OK]
    end
    
    # ---- STRING COMMANDS
    
    # http://code.google.com/p/redis/wiki/SetCommand
    def set(args)
      @data[args.shift] = args.shift
      STATUS[:OK]
    end

    # http://code.google.com/p/redis/wiki/GetCommand
    def get(args)
      if @data[args.first]
        BULK[@data[args.first]]
      else
        [PREFIX[:bulk], -1]
      end
    end
    
    def getset(args)
      key, value = args
      old_data = @data[args.first]
      p old_data
      set(args)
      if old_data
        BULK[old_data]
      else
        [PREFIX[:bulk], -1]
      end
    end
    
    def mget(args)
      MULTI_BULK[args.map { |a| @data[a] }]
    end
    
    def setnx(args)
      return INTEGER[0] if @data[args.first]
      set(args)
      INTEGER[1]
    end
    
    # TODO: SETEX depends on EXPIRE and TTL
    def setex(args)
    end
    
    def mset(args)
      until args.empty?
        key, value = args.shift, args.shift
        set([key, value])
      end
      STATUS[:OK]
    end
    
    def msetnx(args)
      to_set = {}
      until args.empty?
        key, value = args.shift, args.shift        
        return INTEGER[0] if @data[key]
        to_set[key] = value
      end
      
      to_set.each do |key, value|
        set([key, value])
      end
      
      INTEGER[1]
    end
    
    def incr(args)
      key = args.shift
      
      unless @data[key]
        @data[key] = 1
        return INTEGER[1]
      end
      
      if @data[key] && (@data[key].to_i.to_s == @data[key].to_s)
        @data[key] = @data[key].to_i + 1
        return INTEGER[@data[key]]
      end
      
      ERROR["ERR value is not an integer"]
    end

    def incrby(args)
      key = args.shift
      by = args.shift.to_i
      
      unless @data[key]
        @data[key] = by
        return INTEGER[by]
      end
      
      if @data[key] && (@data[key].to_i.to_s == @data[key].to_s)
        @data[key] = @data[key].to_i + by.to_i
        return INTEGER[@data[key]]
      end
      
      ERROR["ERR value is not an integer"]      
    end

    def decr(args)
      key = args.shift
      
      unless @data[key]
        @data[key] = -1
        return INTEGER[-1]
      end
      
      if @data[key] && (@data[key].to_i.to_s == @data[key].to_s)
        @data[key] = @data[key].to_i - 1
        return INTEGER[@data[key]]
      end
      
      ERROR["ERR value is not an integer"]
    end

    def decrby(args)
      key = args.shift
      by = args.shift.to_i
      
      unless @data[key]
        @data[key] = -by
        return INTEGER[-by]
      end
      
      if @data[key] && (@data[key].to_i.to_s == @data[key].to_s)
        @data[key] = @data[key].to_i + -by.to_i
        return INTEGER[@data[key]]
      end
      
      ERROR["ERR value is not an integer"]
    end
    
    def append(args)
      key, value = args
      
      @data[key] ||= ''
      @data[key] += value
      
      INTEGER[@data[key].length]
    end
    
    def substr(args)
      key, startp, endp = args
      return BULK[[nil]] unless @data[key]
      return BULK[@data[key].to_s[startp.to_i..endp.to_i]]
    end
    
    # ---- LIST COMMANDS
    
    def rpush(args)
      key, string = args
      @data[key] ||= []
      return ERROR["ERR Operation against a key holding the wrong kind of value"] unless Array === @data[key]
      @data[key] << string
      INTEGER[@data[key].length]
    end
    
    def lpush(args)
      key, string = args
      @data[key] ||= []
      return ERROR["ERR Operation against a key holding the wrong kind of value"] unless Array === @data[key]
      @data[key].unshift(string)
      INTEGER[@data[key].length]      
    end
    
    def llen(args)
      key = args.shift
      return INTEGER[0] unless @data[key] && Array === @data[key]
      return INTEGER[@data[key].length]
    end
    
    def lrange(args)
      key, startp, endp = args
      return MULTI_BULK[[]] unless @data[key] && Array === @data[key]
      return MULTI_BULK[@data[key][startp.to_i..endp.to_i]]
    end
    
    def ltrim(args)
      key, startp, endp = args
      if @data[key] && Array === @data[key]
        @data[key] = @data[key][startp.to_i..endp.to_i]
      end
      return STATUS[:OK]
    end
    
    def lindex(args)
      key, index = args
      return BULK[[nil]] unless @data[key]
      return BULK[@data[key][index.to_i]]
    end
    
    def lset(args)
      key, index, value = args
      return ERROR["ERR no such key"] unless @data[key]
      return ERROR["ERR Operation against a key holding the wrong kind of value"] unless Array === @data[key]
      return ERROR["ERR index out of range"] if index.to_i < 0 || index.to_i > @data[key].length - 1
      @data[key][index.to_i] = value
      STATUS[:OK]
    end
    
    def lrem(args)
      key, count, value = args
      return ERROR["ERR no such key"] unless @data[key]
      return ERROR["ERR Operation against a key holding the wrong kind of value"] unless Array === @data[key]
      
      old_length = @data[key].size
      
      count.to_i.times do |i|
        if posi = @data[key].index(value.to_s)
          @data[key].delete_at(posi)
        end
      end
      
      INTEGER[old_length - @data[key].size]
    end
    
    def lpop(args)
      key = args.first
      return ERROR["ERR no such key"] unless @data[key]
      return ERROR["ERR Operation against a key holding the wrong kind of value"] unless Array === @data[key]
      BULK[@data[key].shift]
    end

    def rpop(args)
      key = args.first
      return ERROR["ERR no such key"] unless @data[key]
      return ERROR["ERR Operation against a key holding the wrong kind of value"] unless Array === @data[key]
      BULK[@data[key].pop]
    end
    
    # TODO: BLocking POPs.. not sure if it's worth it given this is just an emulator, though.. :-)
    #def blpop(args)
    #  timeout = args.pop
    #end
    #
    #def brpop(args)
    #  timeout = args.pop
    #end
    
    def rpoplpush(args)
      skey, dkey = args
      return BULK[nil] unless @data[skey] && Array === @data[skey]
      @data[dkey] ||= []
      data = @data[skey].pop
      @data[dkey].unshift(data)
      BULK[data]
    end
  end
  
  
  

  # redis-rb uses TCPSocket to communicate with the Redis daemon
  # If we put another TCPSocket /closer/ to Redis, this one will take
  # precedence, but not trample over other TCPSocket classes outside of redis-rb
  class TCPSocket
    def initialize(host, port)
      @emulator = Emulator.new
      @output_queue = []
    end

    def write(data)
      puts "SEND: #{data.inspect}" if TESTING
      cmd, *data = data.split("\r\n")
      if cmd =~ /^\*/
        data.delete_if { |d| d =~ /^\$/ }
        cmd = data.shift
        args = data
        #p cmd
        #p args
      else
        cmd, *args = cmd.split(' ')
      end
      @output_queue += @emulator.send(cmd.downcase.to_sym, args)
      puts "RECV: #{@output_queue.inspect}" if TESTING
    end
    
    def read(b); @output_queue.shift; end
    def gets; @output_queue.shift; end
    def setsockopt(*ignored); end
  end
end


if __FILE__ == $0
  # Poor man's testing
  def assert(c)
    #$an ||= 0
    #puts $an += 1
    abort unless c
    puts
  end

  TESTING = true
  r = Redis.new(:db => 10)
  
  # Clear everything
  assert r.flushall
  
  # Ensure the "a" key does not exist, set it, re-set it, then check its value, existance, and type
  assert !r.exists("a")
  assert r.set("a", 10)
  assert r.set("a", 50)
  assert r.get("a") == "50"
  assert r.exists("a")
  assert r.type("a") == "string"
  
  # Pick a random key - there's only one so far, of course
  assert r.randomkey == "a"
  
  # Remove "a" and then ensure it has no type, does not exist, and is not in the keys list
  assert r.del("a")
  assert r.type("a") == "none"
  assert !r.exists("a")
  assert r.keys("*") == []
  
  # Set keys "a" and "b" and do key lists to prove they exist
  assert r.set("a", "this is a test")  
  assert r.keys("*") == %w{a}
  assert r.set("b", "this is a test too")
  assert r.keys("*") == %w{a b}
  
  # Flush this specific database and ensure it worked
  assert r.flushdb
  assert r.keys("*") == []
  assert r.dbsize == 0
  
  # Test renaming features
  assert r.set("a", 10)
  assert r.rename("a", "b")
  assert r.get("b") == "10"
  assert !r.get("a")
  assert r.set("c", "hello world")
  assert !r.renamenx("c", "b")
  assert r.renamenx("c", "a")
  assert r.type("c") == "none"
  
  # Test moving - in a basic way since redis-rb won't let us select back and forth easily
  assert r.set("a", 10)
  assert r.move("a", 2)
  assert !r.exists("a")
  assert r.flushall
  
  # Test getset to both non-existing and pre-existing keys
  assert r.getset("b", 10) == nil
  assert r.get("b") == "10"
  assert r.set("a", "x")
  assert r.getset("a", "y") == "x"
  assert r.flushdb
  
  # Test mget (multiget)
  assert r.set("a", 100)
  assert r.set("b", 200)
  assert r.set("c", 300)
  assert r.mget("a", "b", "c") == %w{100 200 300}
  assert r.del("b")
  p r.mget("a", "b", "c")
  assert r.mget("a", "b", "c") == ["100", nil, "300"]
  
  # Test setnx (set but not if key already exists)
  assert r.setnx("abc", 10)
  assert r.get("abc") == "10"
  assert !r.setnx("abc", 20)
  assert r.get("abc") == "10"
  assert r.flushdb
  
  # Test mset (multi set)
  assert r.mset("a", 100, "b", 200, "c", 300)
  assert r.mget("a", "b", "c") == %w{100 200 300}
  assert r.flushdb
  
  # Test msetnx (multi set but not if present)
  assert r.msetnx("a", 100, "b", 200, "c", 300) == 1
  assert r.mget("a", "b", "c") == %w{100 200 300}
  assert r.msetnx("a", 1, "b", 2, "c", 3) == 0
  assert r.mget("a", "b", "c") == %w{100 200 300}
  assert r.flushdb
  
  # Test incr, decr, incrby and decrby
  assert r.incr("a") == 1
  assert r.incr("a") == 2
  assert r.set("b", "xyz")
  assert((r.incr("b") rescue :freakout) == :freakout)
  assert r.incrby("a", 2) == 4
  assert r.decr("a") == 3
  assert r.decrby("a", 4) == -1
  assert r.decrby("xxx", 10) == -10
  assert r.incrby("xxx2", 10) == 10
  assert r.flushdb
  
  # Test append (test taken right from the Redis wiki.. :-)
  assert !r.exists("mykey")
  assert r.append("mykey", "Hello ") == 6
  assert r.append("mykey", "World") == 11
  assert r.get("mykey") == "Hello World"
  
  # Test substr
  assert r.set("s", "This is a string")
  assert r.substr("s", 0, 3) == "This"
  assert r.substr("s", -3, -1) == "ing"
  assert r.substr("s", 0, -1) == "This is a string"
  assert r.substr("s", 9, 100000) == " string"
  
  # Test rpush, lpush, llen, ltrim, lrange, lindex, and lset
  assert r.flushdb
  assert r.lpush("a", "hello2") == 1
  assert r.lpush("a", "hello1") == 2
  assert r.llen("a") == 2
  assert r.rpush("a", "hello3") == 3
  assert r.llen("a") == 3
  assert r.lrange("a", 0, -1) == %w{hello1 hello2 hello3}
  assert r.lrange("a", 1, 2) == %w{hello2 hello3}
  assert r.ltrim("a", 1, 2)
  assert r.lrange("a", 0, -1) == %w{hello2 hello3}
  assert r.lindex("a", 0) == "hello2"
  assert r.lindex("a", 1) == "hello3"
  assert r.lindex("a", -2) == "hello2"
  assert r.lset("a", 1, "hello4")
  assert r.lindex("a", 1) == "hello4"
  assert((r.lset("a", 100, "hello4") rescue :freakout) == :freakout)
  assert((r.lset("c", 100, "hello4") rescue :freakout) == :freakout)
  assert r.flushdb
  
  # Test lrem, lpop, rpop, blpop, brpop, and rpoplpush
  assert r.rpush("a", "a")
  assert r.rpush("a", "b")
  assert r.rpush("a", "a")
  assert r.rpush("a", "c")
  assert r.rpush("a", "a")
  assert r.lrem("a", 1, "a") == 1
  assert r.lrange("a", 0, -1) == %w{b a c a}
  assert r.lrem("a", 3, "a") == 2
  assert r.lrange("a", 0, -1) == %w{b c}
  assert r.rpush("a", "a")
  # Do a little side test to make sure numbers don't escape the wrath of lrem
  assert r.rpush("a", 20)
  assert r.rpush("a", 40)
  assert r.lrange("a", 0, -1) == %w{b c a 20 40}
  assert r.lrem("a", 1, 20)
  assert r.lrange("a", 0, -1) == %w{b c a 40}
  # Resume with popping tests!
  assert r.lpop("a") == "b"
  assert r.lrange("a", 0, -1) == %w{c a 40}
  assert r.rpop("a") == "40"
  assert r.lrange("a", 0, -1) == %w{c a}
  assert r.flushdb
  
  # Test rpoplpush
  assert r.rpush("a", "a")
  assert r.rpush("a", "b")
  assert r.rpush("a", "c")
  assert r.rpoplpush("a", "b") == "c"
  assert r.lrange("a", 0, -1) == %w{a b}
  p r.lrange("b", 0, -1)
  assert r.lrange("b", 0, -1) == %w{c}

  
  puts "BINGO!"
end
