class User < ActiveRecord::Base
  # attr_accessible :title, :body
  self.table_name = "User"
  has_many :reviews
  has_many :occurrences, :through => :reviews
end
