require 'rubygems'
require 'em-websocket'
require 'pp'
require 'json'
require 'mq'
require 'active_record'
require 'uuid'
require 'evma_httpserver'


module GitChat
  class ChatServer
    IDLE_TIME = 15      # seconds to wait before setting user idle
    LEAVE_TIME = 30     # seconds to wait before showing user gone
    PRUNE_TIME = 120    # seconds to wait before pruning a connection from @old_connections
    SEND_USER_LIST = 30 # seconds to wait before sending user list to everyone again

    def initialize
      config = YAML.load(File.open("#{File.dirname(__FILE__)}/../db.yml"))
      ActiveRecord::Base.establish_connection(config)

      Dir.glob("#{File.dirname(__FILE__)}/../models/*.rb").each{|model|
        require model
      }

      #Clean out all user/chat relationships in the join table
      Chat.clear_relations

      @run_uuid = UUID.new.generate

      @connections = {}
      #after a user discconects, their connection gets added here indexed by UUID
      @old_connections = {}
    end
    
    #this allows monitoring tools to check whether we're running easily
    class UpServer < EM::Connection
      include EM::HttpServer

      def process_http_request
        response = EM::DelegatedHttpResponse.new(self)
        response.status = 200
        response.content_type 'text/html'
        response.content = '<center><h1>GitChat server up!</h1></center>\n'
        response.send_response
      end
    end
    
    def run
      AMQP.start(:host => "localhost") do
        @mq = MQ.new
  
        EM.start_server '0.0.0.0', 8001, UpServer

        #Prune old connections
        EM.add_periodic_timer(5) do
          @old_connections.delete_if do |uuid, old_conn|
            begin
              case old_conn[:state]
              when :added
                if Time.now - old_conn[:time] > IDLE_TIME
                  old_conn[:state] = :set_idle
                  old_conn[:conn][:repo].chat.set_idle old_conn[:conn][:user]
                end
                false
              when :set_idle
                if Time.now - old_conn[:time] > LEAVE_TIME
                  old_conn[:state] = :set_gone
                  old_conn[:conn][:repo].chat.remove_user old_conn[:conn][:user]
                end
                false
              when :set_gone
                if Time.now - old_conn[:time] > PRUNE_TIME
                  old_conn[:state] = :gone
                  old_conn[:conn][:repo].chat.remove_user old_conn[:conn][:user]
                  old_conn[:conn][:queues].each{|queue| queue.delete}
                  old_conn[:conn][:queues].first
                  DaemonKit.logger.debug("Deleting conn #{old_conn[:conn][:signature]}")
                  true
                end
              end
            rescue
              DaemonKit.logger.debug("Deleting but failed to close: #{$!}")
              true
            end
          end
        end
        
        #Resend the current users periodically
        EM.add_periodic_timer(SEND_USER_LIST) do
          Chat.send_user_lists
        end
        
        EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8000) do |ws|
          ws.onopen do
            DaemonKit.logger.debug "Connection opened on #{ws.signature}"
          end
    
          ws.onmessage do |json|
            message = JSON.parse(json)
            case message["event"]
            when "new connection handshake" then new_connection(message, ws)
            when "new message" then new_message(message, ws)
            end
          end

          ws.onclose do
            DaemonKit.logger.debug "Connection #{ws.signature} closed"
            conn = @connections.delete ws.signature
            begin
              @old_connections[conn[:uuid]] = {:conn => conn, :time => Time.now, :state => :added}
            rescue
              DaemonKit.logger.debug "Failed to save old connection for #{ws.signature}: #{$!}"
            end
          end
    
          def new_connection(message, ws)
            DaemonKit.logger.debug "New connection on #{ws.signature}"
            begin
              conn = nil
              if old_conn = @old_connections[message['data']['uuid']]
                conn = old_conn[:conn]
                case old_conn[:state]
                when :set_idle
                  conn[:repo].chat.set_unidle conn[:user]
                when :set_gone
                  conn[:repo].chat.add_user conn[:user]
                end
                @old_connections.delete old_conn
                DaemonKit.logger.debug "Reconnecting on #{ws.signature}"
              else
                repo = "#{message['data']['creator']}/#{message['data']['repository']}"
                uuid = UUID.new.generate
        
                user_session = UserSession.find_by_session_key(message['data']['session_key'])
                return unless user_session
                user = user_session.user
        
                repository = User.find_by_username(
                  message['data']['creator']
                ).repositories.find_by_name(message['data']['repository'])

                repos_queue = @mq.queue("repos#{@run_uuid}#{ws.signature}").bind(@mq.topic('gitchat:repositories'), :key => repo)        
                chats_queue = @mq.queue("chats#{@run_uuid}#{ws.signature}").bind(@mq.topic('gitchat:chats'), :key => repo)
                users_queue = @mq.queue("users#{@run_uuid}#{ws.signature}").bind(@mq.topic('gitchat:users'), :key => repo)

                queues =  [repos_queue, chats_queue, users_queue]
                conn = {:repo => repository, :user => user, :uuid => uuid, :queues => queues, :signature => ws.signature}
                repository.chat.add_user user if conn[:user]
                DaemonKit.logger.info "Connecting on #{ws.signature}"
              end

              conn[:queues].each{|queue|
                queue.subscribe do |msg|
                  ws.send(msg)
                end
              }
      
              @connections[ws.signature] = conn
            
              ws.send({
                :event => "new connection handshake",
                :data => {
                  :uuid => conn[:uuid],
                  :users => conn[:repo].chat.users.collect{|user| user.to_hash}
                }
              }.to_json)
            rescue => e
              send_error("Failed to connect to backend", $!, ws)
              DaemonKit.logger.exception e
            end
          end
        end
        def new_message(message, ws)
          begin
            conn = @connections[ws.signature]
            if conn[:user]
              m = Message.new(
                :author => conn[:user],
                :text => message['data']['text'],
                :chat => conn[:repo].chat
              )
              m.save!
            end
          rescue
            send_error("Failed to receive message", $!, ws)
            DaemonKit.logger.debug "Error receiving message: #{$!}"
          end
        end
        def send_error(message, error, ws)
          ws.send({"event" => "error", "data" => {"message" => message, "error" => error}}.to_json)
        end
  
        def user_for_session(session)
          user_session = UserSession.find_by_session_key(session)
          user_session.user
        end
      end
    end
  end
end
