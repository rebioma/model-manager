class User < ActiveRecord::Base
  # attr_accessible :title, :body
  self.table_name = "user"
  has_many :reviews, :foreign_key => "userid"
  has_many :occurrences, :through => :reviews
end
