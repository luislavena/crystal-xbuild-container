# A very basic HTTP server
require "http/server"

server = HTTP::Server.new do |context|
  context.response.content_type = "text/plain"
  context.response.print "Hello world, got #{context.request.path}!"
end

address = server.bind_tcp(8080)
puts "Listening on http://#{address}"

# This call blocks until the process is terminated
server.listen
