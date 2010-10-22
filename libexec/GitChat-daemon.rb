require_relative '../lib/gitchat.rb'

DaemonKit::Application.running! do |config|
  # Trap signals with blocks or procs
  # config.trap( 'INT' ) do
  #   # do something clever
  # end
  # config.trap( 'TERM', Proc.new { puts 'Going down' } )
end

DaemonKit.logger.info "GitChat server running..."
server = GitChat::ChatServer.new
server.run