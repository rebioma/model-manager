class Occurrence < ActiveRecord::Base
  # establish_connection "rebioma_#{Rails.env}"
  self.table_name = "Occurrence"
  self.primary_key = :ID
  alias_attribute :acceptedspecies, :AcceptedSpecies
  alias_attribute :decimallatitude, :DecimalLatitude
  alias_attribute :decimallongitude, :DecimalLongitude
  alias_attribute :yearcollected, :YearCollected
  attr_accessible :acceptedspecies, :decimallatitude, :decimallongitude
  has_many :reviews
  has_many :users, :through => :reviews
  scope :reviewed, :conditions => {:reviewed => true}
  scope :validated, :conditions => {:validated => true}
  scope :public_record, :conditions => {:public_record => true}
  scope :vettable, :conditions => {:vettable => true}
  scope :private_vettable, :conditions => ['public_record = ? AND vettable = ?', false, true]
end
