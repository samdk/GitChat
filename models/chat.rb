class Chat < ActiveRecord::Base
  has_and_belongs_to_many :users
  belongs_to :repository
  has_many :messages

  def add_user user
    unless self.users.include? user
      self.users << user 
      push_to_amqp("user join", user)
    end
    self.save!
  end
  
  def remove_user user
    push_to_amqp("user leave", user) if self.users.delete(user)
    self.save!
  end
  
  def set_idle user
    push_to_amqp("user idle", user)
  end
  
  def set_unidle user
    push_to_amqp("user unidle", user)
  end
  
  def self.clear_relations
    ActiveRecord::Base.connection.execute("DELETE FROM chats_users WHERE 1 = 1")
  end
  
  def self.send_user_lists
    self.joins(:users).uniq.each do |chat|
      MQ.new.topic("gitchat:users").publish(
        {
          :event => "chat users",
          :data => chat.users.collect{|user| user.to_hash}
        }.to_json,
        :key => chat.repository.repo
      )
    end
  end
  
  private
  def push_to_amqp(event, user)
    MQ.new.topic("gitchat:users").publish(
      {
        :event => event,
        :data => user.to_hash
      }.to_json,
      :key => self.repository.repo
    )
  end
end
