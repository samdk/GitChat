require 'sanitize'

class Message < ActiveRecord::Base
  attr_accessible :text, :author, :chat
  
  validates_presence_of  :text
  
  belongs_to :author, :class_name => "User", :foreign_key => "author_id"
  belongs_to :issue
  belongs_to :commit
  belongs_to :chat
  
  before_save :sanitize_input
  after_save :push_to_mq
  
  def to_hash
    {
      :author => self.author.to_hash,
      :time => self.created_at.to_i * 1000,
      :text => self.text,
      :repository => self.chat.repository.repo
    }
  end
  
  private
  def sanitize_input
    self.text = Sanitize.clean(self.text)
  end

  def push_to_mq
    amqp = MQ.new.topic("gitchat:chats").publish(
      {
        :event => "new message",
        :data => self.to_hash
      }.to_json,
      :key => self.chat.repository.repo
    )
  end
end
