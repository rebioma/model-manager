class Review < ActiveRecord::Base
  # attr_accessible :title, :body
  self.table_name = "record_review"
  self.primary_key = "Id"
  belongs_to :occurrence
  belongs_to :user
end
