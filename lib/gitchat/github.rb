require 'rest_client'
require 'yaml'

module Github
  class Base
    def self.api_url(point, token)
      #auth = token ? "#{username}%2Ftoken:#{token}@" : ""
      "http://github.com/api/v2/yaml#{point}?access_token=#{token}"
    end
  end
  class User
    def self.find(username)
      puts "Finding user: #{username}"
      #yaml = RestClient.get Github.api_uri("/user/show/#{username}", username, nil)
      yaml = RestClient.get "http://github.com/api/v2/yaml/user/show/#{username}"
      user = YAML.load(yaml)["user"]
      
      {
        :username => user["login"],
        :real_name => user["name"],
        :gravatar => user["gravatar_id"],
        :profile_link => "http://github.com/#{user["login"]}/"
      }
    end
  end
  
  class Repository
    def self.find_by_user(user, auth_user=nil, token=nil)
      puts Github::Base.api_url("/repos/show/#{user}", token)
      yaml = RestClient.get Github::Base.api_url("/repos/show/#{user}", token)
      repos = YAML.load(yaml)["repositories"]
      repos.collect do |repo|
        begin
          yaml = RestClient.get Github::Base.api_url("/repos/show/#{repo[:owner]}/#{repo[:name]}/network", token)
          network = YAML.load(yaml)["network"]
        rescue
          puts "failed on /repos/show/#{repo[:owner]}/#{repo[:name]}/network"
          network = []
        end
          #find the parent, which is the only one not a fork
        parent = network.find{|repo| !repo[:fork]}
        parent_string = "#{parent[:owner]}/#{parent[:name]}" if parent
        repo_hash = hash_for_repo(repo, parent_string)
        repo_hash[:forks] = network.collect{|fork| 
          hash_for_repo(fork, parent_string)
        }.reject{|fork| fork[:link] == repo_hash[:link]}
        repo_hash
      end if repos
    end
    
    private
    def self.hash_for_repo(repo, parent=nil)
      {
        :link => repo[:url],
        :name => repo[:name],
        :description => repo[:description],
        :creator => repo[:owner],
        :parent_repo => parent,
        :private => repo[:private]
      }
    end
  end
  
  class Issues
    def self.find_by_repository(repo, open=true, username=nil, token=nil)
      yaml = RestClient.get Github::Base.api_url("/issues/list/#{repo}/#{open ? "open" : "closed"}", token)
      issues = YAML.load(yaml)["issues"]
      issues.collect do |issue|
        {
          :creator => issue["user"],
          :title => issue["title"],
          :text => issue["body"],
          :github_id => issue["number"],
          :repo => "#{username}/#{repo}",
          :created_date => issue["created_at"],
          :closed_date => issue["closed_at"]
        }
      end
    end
    
    def self.comments_for_issue(repo, issue, username=nil, token=nil)
      yaml = RestClient.get Github::Base.api_url("/issues/comments/#{repo}/#{issue}", token)
      comments = YAML.load(yaml)["comments"]
      comments.collect do |comment|
        {
          :gravatar => comment["gravatar_id"],
          :created_at => comment["created_at"],
          :author => comment["user"],
          :text => comment["body"]
        }
      end
    end
  end
  
  class Commits
    def self.find_by_repository(repo, branch="master", username=nil, token=nil)
      yaml = RestClient.get Github::Base.api_url("/commits/list/#{repo}/#{branch}", token)
      commits = YAML.load(yaml)["commits"]
      commits.collect do |commit|
        {
          :hash => commit["id"],
          :repository => repo,
          :branch => branch,
          :time => commit["committed_date"],
          :commit_msg => commit["message"],
          :author => commit["committer"]["login"]
        }
      end
    end
  end
end
