class Repository < ActiveRecord::Base
  attr_accessible :link, :name, :private, :should_be_pushed
  
  validates_presence_of  :link
  validates_presence_of  :name
  validates_inclusion_of :private, :in => [true, false]
  
  belongs_to :creator, :class_name => "User"
  has_one :chat
  has_and_belongs_to_many :forks,
    :class_name => "Repository",
    :foreign_key => "this_repository_id",
    :association_foreign_key => "other_repository_id"
  has_many :issues
  belongs_to :parent_repo, :class_name => "Repository"
  
  has_and_belongs_to_many :users
  
  validates_uniqueness_of :name, :scope => :creator_id
  
  #after_save :push_to_mq, :if => :should_be_pushed
  after_create :push_to_mq
  
  #string like "username/reponame" -- uniquely id's a repo
  def repo
    "#{creator.username}/#{name}"
  end
  
  def update_commits(username, token)
    commits = Github::Commits.find_by_repository(self.repo, "master", username, token)
    commits.each{|hash|
      commit = Commit.find_by_hash(hash[:hash])
      author = User.find_or_create(hash[:author]) if hash[:author] != ""
      
      commit = Commit.new if !commit
      commit.hash = hash[:hash]
      commit.repository = self
      commit.commit_msg = hash[:commit_msg]
      commit.author = author if author
      commit.time = hash[:time]
      commit.branch = hash[:branch]
      commit.save! 
    }
  end
  
  def update_issues(username, token)
    current_issues = self.issues.reject{|issue| !issue.open}.collect{|issue| issue.github_id.to_i}.uniq
    issues = Github::Issues.find_by_repository(self.repo, true, username, token)
    issues.each{|hash|
      unless issue = Issue.find_by_github_id(current_issues.delete(hash[:github_id]))
        issue = Issue.new
      end
      issue.creator = User.find_or_create(hash[:creator])
      issue.title = hash[:title]
      issue.text = hash[:text]
      issue.repository = self
      issue.created_date = hash[:created_date]
      issue.github_id = hash[:github_id]
      issue.save!
    }
    # if current_issues has anything left in it, they must be closed tickets, so we should
    # look at those for info
    if current_issues.size > 0
      closed_issues = Github::Issues.find_by_repository(self.repo, false, username, token)
      current_issues.each{|github_id|
        comments = Github::Issues.comments_for_issue(self.repo, github_id, username, token)
        hash = closed_issues.find{|hash| hash[:github_id] == github_id}
        issue = Issue.find_by_github_id(github_id)
        issue.creator = User.find_or_create(hash[:creator])
        issue.title = hash[:title]
        issue.text = hash[:text]
        issue.repository = self
        issue.created_date = hash[:created_date]
        issue.closed_date = hash[:closed_date]
        issue.open = false
        if closing_comment = comments.find{|comment| (comment[:created_at] - hash[:closed_date]).abs < 50000}
          issue.close_msg = closing_comment[:text]
          issue.closer = User.find_or_create(closing_comment[:author])
          issue.closer.gravatar = closing_comment[:gravatar]
          issue.closer.save!
        end
        issue.save!
      }
    end
  end
  
  def to_hash
    {
      :link => self.link,
      :name => self.name,
      :creator => self.creator.username,
      :parent_repo => self.parent_repo ? self.parent_repo.repo : nil,
      :private => self.private
    }
  end
  
  def self.create_from_hash(hash, username, token)
    unless repo = Repository.find_by_link(hash[:link])
      repo = Repository.new(
        :link => hash[:link],
        :name => hash[:name],
        :private => hash[:private]
      )
      repo.creator = User.find_or_create(hash[:creator])
      repo.save!
    end
    repo
  end

  def self.find_by_name_pair(username,reponame)
    Repository.find(:username => username, :reponame => reponame)
  end
  
  private
  def push_to_mq
    amqp = MQ.new.topic("gitchat:repositories").publish(
      {
        :event => "new repository",
        :data => self.to_hash.to_json
      },
      :key => repo
    )
  end
end
