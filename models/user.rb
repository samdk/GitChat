class User < ActiveRecord::Base
  USER_NOT_FOUND = "user_not_found"
  attr_accessible :profile_link, :gravatar, :username, :real_name, :seen_before, :stub

  validates_presence_of   :username
  validates_uniqueness_of :username
  validates_inclusion_of  :seen_before, :in => [true, false]
  
  has_and_belongs_to_many :repositories
  
  has_many :user_sessions

  def chat_name
    real_name ? real_name.split(' ')[0] : username
  end
  
  def to_hash
    {
      :profile_link => self.profile_link,
      :gravatar => self.gravatar,
      :username => self.username,
      :real_name => self.real_name,
      :seen_before => self.seen_before
    }
  end
  
  def update_repositories(auth_user, token)
    repos = Github::Repository.find_by_user(self.username, auth_user, token)
    #if the repo isn't in the db, add it
    repos.each do |repo|
      if repo_rec = Repository.find_by_link(repo[:link])
        repo_rec.update_attributes(repo)
      else
        repo_rec = Repository.create_from_hash repo
        self.repositories << repo_rec
      end
      repo_rec.creator = self
      repo_rec.save!
    end
  end

  def self.find_or_create(username)
    user = nil
    begin
      user = self.find_by_username(username)
      if !user
        user = User.new(
          :username => username,
          :profile_link => "https://github.com/#{username}/"
        )
        user.save!
      end
    rescue
    end
    user
  end
  
  def self.create_from_github(username, token=nil)
    create_from_hash(Github::User.find(username), username, token)
  end
  
  def self.create_from_hash(hash, username, token)
    #we may have created the user but not gotten all their info
    user = User.find_by_username(username)
    if user && user.stub
        user.gravatar = hash[:gravatar]
        user.real_name = hash[:real_name]
        user.stub = false
    elsif !user
      user = User.new(hash)
    end
    user.save!
    user.update_repositories(username, token)
    user
  end
end
