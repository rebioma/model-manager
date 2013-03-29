class Occurrence < ActiveRecord::Base
  # establish_connection "rebioma_#{Rails.env}"
  #self.table_name = "Occurrence"
  self.primary_key = "ID"
  #alias_attribute :acceptedspecies, :AcceptedSpecies
  #alias_attribute :decimallatitude, :DecimalLatitude
  #alias_attribute :decimallongitude, :DecimalLongitude
  #alias_attribute :yearcollected, :YearCollected
  attr_accessible :AcceptedSpecies, :DecimalLatitude, :DecimalLongitude
  has_many :reviews, :foreign_key => "occurrenceId"
  has_many :users, :through => :reviews
  #scope :reviewed, :conditions => {:reviewed => true}
  #scope :validated, :conditions => {:Validated => true}
  #scope :public_record, :conditions => {:Public => true}
  #scope :vettable, :conditions => {:Vettable => true}
  #scope :private_vettable, :conditions => ['Public = ? AND Vettable = ?', false, true]
end
