class Commit < ActiveRecord::Base
  attr_accessible :hash, :commit_msg, :parent, :time, :branch
  
  validates_presence_of :hash
  validates_presence_of :branch
  validates_presence_of :commit_msg
  
  validates_uniqueness_of :hash
  
  belongs_to :repository
  belongs_to :author, :class_name => "User"
  
  after_create :push_to_mq
  
  def to_hash
    {
      :hash => self.hash,
      :repository => repository.repo,
      :commit_msg => self.commit_msg,
      :author => author.to_hash,
      :time => self.time.to_i*1000
    }
  end
  
  private
  def push_to_mq
    amqp = MQ.new.topic("gitchat:repositories").publish(
      {
        :event => "new commit",
        :data => self.to_hash
      }.to_json,
      :key => repository.repo
    )
  end
end