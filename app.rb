require 'rubygems'
require 'sinatra'
require 'erb'
require 'oauth2'
require 'em-websocket'
require 'logger'
require 'mq'
require 'active_record'
require 'yaml'
require 'json'

# database connection
config = YAML.load(File.open("db.yml"))
ActiveRecord::Base.establish_connection(:adapter => config['adapter'],
                                        :host => config['host'],
                                        :database => config['database'],
                                        :username => config['username'],
                                        :password => config['password'])

require './lib/gitchat/github'
require './models/chat'
require './models/commit'
require './models/issue'
require './models/message'
require './models/fork_list'
require './models/repository'
require './models/user'
require './models/user_session'

# ruby 1.9.2 fixes
enable :run
enable :sessions
set :views, File.dirname(__FILE__) + '/views'
set :public, File.dirname(__FILE__) + '/public'

module RR
  class App < Sinatra::Application
    github_config = YAML.load(File.open("github_config.yml"))
    CLIENT_SERVER_ID     = github_config["client_server_id"]
    CLIENT_SERVER_SECRET = github_config["client_server_secret"]
    CLIENT_LOCAL_ID      = github_config["client_local_id"]
    CLIENT_LOCAL_SECRET  = github_config["client_local_secret"]
    AUTH_URL             = "https://github.com/login/oauth/authorize"
    ACCESS_TOKEN_PATH    = "https://github.com/login/oauth/access_token"
    
    before do
      #AMQP.connect(:host => "localhost")
      if session[:session_key]
        sess = UserSession.find_by_session_key(session[:session_key])
        if sess
          @current_user = sess.user
          sess.last_seen = Time.now
          sess.save
        else
          session.delete(:session_key)
        end
      end
    end

  
    get '/' do
      @oauth_link = '/login'
      @no_header = true unless @current_user
      @popular = Chat.all.select {|c| !c.repository.private}.sort_by {|c| -c.users.size}[0,3]
      @newest = Chat.order("created_at DESC").all.select {|c| !c.repository.private}[0,3]
      erb :index
    end

    get '/login_as/:user' do
      # lets you log in as any user. Useful for testing, though
      # potentially a security risk
      if request.env['HTTP_HOST'].split(":")[0] == "localhost"
        user_hash = {
          :profile_link => "https://github.com/#{params[:user]}",
          :username     => params[:user],
          :seen_before  => false,
          :real_name => params[:user] # need this for chat to work
        }
        user = User.create_from_hash(user_hash, params[:user], nil)
        sess = UserSession.create(:access_token => "12345",
                                  :user => user,
                                  :last_seen => Time.now)
        session[:session_key] = sess.session_key
      end
      redirect '/'
    end

    get '/login' do
      session[:back] = back
      redirect oauth.authorize_url(:redirect_uri => oauth_redirect_url, :scope => "user,repo")
    end

    get '/logout' do
      UserSession.find_by_session_key(session[:session_key]).destroy
      session.delete(:session_key)
      redirect back
    end

    get '/auth'  do
      access_token = oauth.get_access_token(params[:code], :redirect_uri => oauth_redirect_url)
      token = access_token.token
      
      user_json = JSON.parse(access_token.get("/api/v2/json/user/show"))['user']
      user_hash = {
        :profile_link => "https://github.com/#{user_json['login']}",
        :gravatar     => user_json['gravatar_id'],
        :username     => user_json['login'],
        :real_name    => user_json['name'],
        :seen_before  => false
      }
      user = User.create_from_hash(user_hash, user_hash[:username], token)
      puts "Finished creating user"
      sess = UserSession.create(:access_token => token,
                                :user => user,
                                :last_seen => Time.now)

      session[:session_key] = sess.session_key
      
      if session[:back]
        b = session[:back]
        session.delete(:back)
        redirect b
      else
        redirect '/'
      end
    end

    # display chat room
    get '/:creator/:name' do
      # this page doesn't have shared UI elements
      @no_header = true ; @no_features = true ; @no_footer = true

      @creator = User.find_by_username(params[:creator])
      @repo = @creator.repositories.find_by_name(params[:name]) if @creator
      if @repo && @repo.chat
        if !@repo.private || (@current_user && @repo.private && @current_user.repositories.include?(@repo))
          @session_key = session[:session_key] if @current_user
          @is_chat = true
          
          m = Message.order("created_at ASC").find_all_by_chat_id(@repo.chat.id)
          msgs = m.last(50)
          @first_message_id = @repo.chat.messages.sort_by {|m| m.id}.first.id if !@repo.chat.messages.empty?
          @messages = msgs

          @title = "#{repo_abbr(@repo)} - GitChat - Chat for GitHub"

          erb :chat
        else
          403
        end
      else
        404
      end
    end

    # display chat room
    get '/:creator/:name/messages/:before' do
      content_type :json
      @creator = User.find_by_username(params[:creator])
      @repo = @creator.repositories.find_by_name(params[:name]) if @creator
      if @repo && @repo.chat
        if !@repo.private || (@current_user && @repo.private && @current_user.repositories.include?(@repo))
          @session_key = session[:session_key] if @current_user
          
          msgs = Message.order("created_at ASC").where(['chat_id = ? AND created_at < ?', @repo.chat.id, Time.at(params[:before].to_i)]).last(50)
          msgs2 = msgs.collect do |msg|
              {'author' => msg.author.chat_name,
               'id' => msg.id,
               'text' => msg.text,
               'created_at' => msg.created_at.to_i,
               'issue_id' => msg.issue_id,
               'commit_id' => msg.commit_id}
          end
          msgs2.to_json
        else
          403
        end
      else
        404
      end
    end

    # create new chat room
    get '/:creator/:name/create' do
      @creator = User.find_by_username(params[:creator])
      @repo = @creator.repositories.find_by_name(params[:name]) if @creator
      if @repo.chat
        redirect "/#{params[:creator]}/#{params[:name]}"
      elsif @repo
        if @current_user.repositories.include? @repo
          # generate network so we can show forks
          token = UserSession.find_by_session_key(session[:session_key]).access_token
          @repo.create_network @current_user, token
          chat = Chat.create(:repository => @repo)
          redirect "/#{@repo.creator.username}/#{@repo.name}"
        else
          403
        end
      else
        404
      end
    end

    def oauth
      #puts YAML::dump(request)
      http_host = request.env['HTTP_HOST']
      #puts request.url.split(":")[0] 
      if (http_host.split(":")[0] == "localhost")
        # For testing. Probably should do this by separating into production and development
        client_id=CLIENT_LOCAL_ID
        client_secret = CLIENT_LOCAL_SECRET
      else 
        client_id=CLIENT_SERVER_ID
        client_secret = CLIENT_SERVER_SECRET
      end

      OAuth2::Client.new(client_id, client_secret,
                         :site => "https://github.com/login/oauth",
                         :authorize_path => AUTH_URL,
                         :access_token_path => ACCESS_TOKEN_PATH
                        ).web_server

    end

    def oauth_redirect_url
      #if (request.url.split(":")[0] == "localhost") 
      #  return "http://bit.ly/bkb4Zo"
      #end
      uri = URI.parse(request.url)
      uri.path  = '/auth'
      uri.query = nil
      uri.to_s
    end

    configure do
      LOGGER = Logger.new('log/sinatra.log')
    end

    helpers do
      def logger
        LOGGER
      end

      def gravatar_url(hash,size)
        "http://gravatar.com/avatar/#{hash}?s=#{size}&r=pg&d=mm"
      end

      def user_url(user)
        "http://github.com/#{user.username}"
      end

      def repo_url(repo)
        "http://github.com/#{repo_abbr(repo)}"
      end

      def repo_link(repo)
        "<a href=\"#{repo_url(repo)}\">#{repo_abbr(repo)}</a>"
      end

      def repo_abbr(repo)
        "#{repo.creator.username}/#{repo.name}"
      end

      def chat_link(repo,text=nil,classes=nil)
        abbr = repo_abbr(repo)
        link("/#{abbr}",text.nil? ? abbr : text,classes)
      end

      def create_chat_link(repo,text=nil,classes=nil)
        abbr = repo_abbr(repo)
        link("/#{abbr}/create",text.nil? ? abbr : text,classes)
      end

      def link(link,text,classes=nil)
        l = []
        l << "<a href=\"#{link}\""
        #l << " id=\"#{id}\"" if id
        l << " class=\"#{classes.join(' ')}\"" if classes && !classes.empty?
        l << ">#{text}</a>"
        l.join('')
      end
    end

  end
end
