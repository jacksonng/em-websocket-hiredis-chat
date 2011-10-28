require 'rubygems'
require 'em-websocket'
require 'json'
require 'em-hiredis'

CHANNEL_NAME = 'chatter'

EM.run do
  @sockets = []

  redis_publisher = EM::Hiredis.connect
  redis_subscriber = EM::Hiredis.connect
  
  #puts redis_publisher.connection_completed
  
  #puts redis_publisher.connected?.errback{|e| puts e}
  
  response_deferrable = redis_publisher.set('foo', 'bar')
  response_deferrable.errback {|e| puts e}
  #SET mykey "Hello"
  
  redis_publisher.callback { puts "Redis now connected" }
  redis_publisher.onclosed { puts "Redis got error" }

  redis_subscriber.subscribe(CHANNEL_NAME)
  puts "subscribing to redis channel: #{CHANNEL_NAME}"

  redis_subscriber.on(:message) { |channel, message|
    key,json = message.split('::::')
    #p "redis message: #{json}"
    @sockets.select{|s| s.request['sec-websocket-key']!=key}.map{|s| s.send(json)}
  }

  EventMachine::WebSocket.start(:host => 'localhost', :port => 8080) do |sockie|
    sockie.onopen do
      p "Websocket opened - #{sockie.request['sec-websocket-key']}"
      @sockets << sockie
    end
    
    sockie.onmessage do |m|
      hash = JSON.parse(m)
      #p "sockie message: #{hash}"
      redis_publisher.publish(CHANNEL_NAME, "#{sockie.request['sec-websocket-key']}::::#{m}")
    end
    
    sockie.onclose do
      p "Websocket closed - #{sockie.request['sec-websocket-key']}"
      @sockets.delete sockie
    end
  end
end
