require 'active_record'
require 'rspec'

begin
  config = YAML.load(File.open("#{File.dirname(__FILE__)}/../db.yml"))
rescue
  $stderr.puts "You must create a file db.yml in the root directory with database configuration"
  exit
end

ActiveRecord::Base.establish_connection(config)

Dir.glob("#{File.dirname(__FILE__)}/../models/*.rb").each do |model|
	begin
		require model
	rescue
		$stderr.puts "Failed to load #{model}: #{$!}"
	rescue LoadError
		$stderr.puts "Failed to load #{model}: syntax error"
	end
end


describe User, "when instantiated" do
  it "should instantiate user models" do
    user = User.new :profile_link => "http://something/", 
      :gravatar => "klqj23h4lq",
      :username => "mwylde",
      :real_name => "Micah Wylde"
  end
end

describe Chat, "when instantiated" do
  it "should instantiate chat models" do
    chat = Chat.new
  end
end

describe Commit, "when instantiated" do
  it "should instantiate commit models" do
    commit = Commit.new :hash => "asdf2l3k4j2kl34",
      :commit_msg => "Hello",
      :tree => "kj23h4lkj2h34",
      :parent => "kjh2l3j4"
    end
end

describe FeedItem, "when instantiated" do
  it "should instantiate users models" do
    feeditem = FeedItem.new :type => FeedItem::ISSUE_CREATE,
      :time => DateTime.now
  end
end

describe Issue, "when instantiated" do
  it "should instantiate users models" do
    issue = Issue.new :title => "Test",
      :text => "Something",
      :github_ib => "jkl23h4jk234",
      :created_date => DateTime.now
  end
end

describe Message, "when instantiated" do
  it "should instantiate users models" do
    message = Message.new :time => DateTime.now,
      :text => "Hello"
  end
end

describe Repository, "when instantiated" do
  it "should instantiate users models" do
    repository = Repository.new :link => "http://asdf234.com",
      :name => "my-repo"
  end
end