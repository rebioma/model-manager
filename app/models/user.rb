class User < ActiveRecord::Base
  # attr_accessible :title, :body
  self.table_name = "User"
  has_many :reviews, :foreign_key => "userId"
  has_many :occurrences, :through => :reviews
end
