class AscModel < ActiveRecord::Base
  attr_accessible :accepted_species, :model_location, :index_file
  self.table_name = "asc_model"
end
