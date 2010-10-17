require 'spec'
require_relative 'spec_helper'
require 'github_chat/github'

begin
  token_doc = File.open("#{File.dirname(__FILE__)}/github_auth.yml")
  GITHUB_USERNAME = YAML.load(token_doc)["username"]
  GITHUB_TOKEN = YAML.load(token_doc)["username"]
rescue
  puts "You must create a github_auth.yml file in the tests dir"
  exit
end
describe "Github::User" do
  it "should get public info about users" do
    Github::User.find("mwylde").should == {
      :real_name => "Micah Wylde",
      :username => "mwylde",
      :gravatar => "1c79e00f296abdbfe51b170e442eff04",
      :profile_link => "http://github/mwylde/"
    }
  end
end