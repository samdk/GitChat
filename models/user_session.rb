require 'digest/sha1'

class UserSession < ActiveRecord::Base
  belongs_to :user
  validates_associated :user

  validates_presence_of :session_key
  validates_presence_of :access_token

  before_validation :generate_session_key, :on => :create

  private
    def generate_session_key
      self.session_key = Digest::SHA1.hexdigest(Time.now.to_s + rand.to_s)
      self
    end
end
