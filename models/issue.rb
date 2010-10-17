class Issue < ActiveRecord::Base
  attr_accessible :title, :text, :github_id, :close_msg, :created_date, :closed_date, :open
  
  validates_presence_of :title
  validates_presence_of :text
  validates_presence_of :github_id
  validates_presence_of :created_date
  
  validates_uniqueness_of :github_id, :scope => :repository_id
  
  belongs_to :creator, :class_name => "User"
  belongs_to :repository
  belongs_to :closer, :class_name => "User"
  
  after_create :push_to_mq
  after_save :push_to_mq, :if => "@push_on_next_save"
  
  def to_hash
    {
      :creator => self.creator.to_hash,
      :title => self.title,
      :text => self.text,
      :github_id => self.github_id,
      :repo => self.repository.repo,
      :created_date => self.created_date.to_i * 1000,
      :closer => self.closer ? self.closer.to_hash : nil,
      :close_msg => self.close_msg,
      :closed_date => self.closed_date.to_i * 1000,
      :open => self.open
    }
  end
  
  def write_attribute(attr_name, value)
    super
    attribute_changed(attr_name, value)
  end
  
  private
  def push_to_mq
    amqp = MQ.new.topic("gitchat:repositories").publish(
      {
        :event => "new issue",
        :data => self.to_hash
      }.to_json,
      :key => self.repository.repo
    )
    @push_on_next_save = false
  end
  
  def attribute_changed(attr_name, value)
    @push_on_next_save = true if attr_name == "open"
  end
  
  
end