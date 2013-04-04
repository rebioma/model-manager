class Review < ActiveRecord::Base
  attr_accessible :userId, :occurrenceId, :reviewed, :reviewed_date
  self.table_name = "record_review"
  self.primary_key = "Id"
  belongs_to :occurrence
  belongs_to :user
end
