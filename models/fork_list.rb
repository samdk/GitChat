class ForkList < ActiveRecord::Base
  has_many :repositories
  belongs_to :parent, :class_name => "Repository"
end
