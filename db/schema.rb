# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130605045330) do

  create_table "AscData", :force => true do |t|
    t.string  "data_type",        :limit => 16
    t.string  "file_name",        :limit => 128, :null => false
    t.float   "south_boundary",                  :null => false
    t.float   "west_boundary",                   :null => false
    t.float   "north_boundary",                  :null => false
    t.float   "east_boundary",                   :null => false
    t.integer "width"
    t.integer "height"
    t.float   "min_value",                       :null => false
    t.float   "max_value",                       :null => false
    t.string  "description",      :limit => 128
    t.string  "units",            :limit => 16
    t.string  "variable_type",    :limit => 16
    t.string  "year",             :limit => 8
    t.string  "env_data_type"
    t.string  "env_data_subtype"
    t.text    "metadata"
  end

  create_table "OccurrenceComments", :force => true do |t|
    t.integer   "oid",           :null => false
    t.integer   "uid",           :null => false
    t.text      "userComment",   :null => false
    t.timestamp "dateCommented", :null => false
  end

  create_table "OccurrenceUpdates", :force => true do |t|
    t.timestamp "lastupdate", :null => false
  end

  create_table "Role", :force => true do |t|
    t.string "name_en",        :null => false
    t.string "name_fr",        :null => false
    t.text   "description_en", :null => false
    t.text   "description_fr", :null => false
  end

  create_table "User", :force => true do |t|
    t.string  "first_name",    :limit => 128
    t.string  "last_name",     :limit => 128
    t.string  "open_id",       :limit => 32
    t.string  "email",         :limit => 128
    t.boolean "approved",                     :default => false
    t.integer "vetter",                       :default => 0
    t.integer "data_provider",                :default => 0
    t.string  "institution",   :limit => 128
    t.string  "password_hash", :limit => 256
    t.string  "session_id",    :limit => 256
  end

  create_table "UserRoles", :force => true do |t|
    t.integer "userId", :null => false
    t.integer "roleId", :null => false
  end

  create_table "asc_model", :force => true do |t|
    t.string "accepted_species", :limit => 256, :null => false
    t.string "model_location",   :limit => 256, :null => false
    t.string "index_file",       :limit => 256
  end

  create_table "collaborators", :force => true do |t|
    t.integer "userId",   :null => false
    t.integer "friendId", :null => false
  end

  add_index "collaborators", ["friendId"], :name => "friendId"
  add_index "collaborators", ["userId"], :name => "userId"

  create_table "occurrence", :primary_key => "ID", :force => true do |t|
    t.integer   "Owner",                                                                   :null => false
    t.boolean   "Public",                                                                  :null => false
    t.boolean   "Vettable",                                                                :null => false
    t.boolean   "Validated",                                                               :null => false
    t.boolean   "Vetted",                                                                  :null => false
    t.boolean   "TapirAccessible",                                                         :null => false
    t.string    "email",                                 :limit => 128
    t.text      "VettingError"
    t.text      "ValidationError"
    t.text      "BasisOfRecord"
    t.integer   "YearCollected"
    t.text      "Genus"
    t.text      "SpecificEpithet"
    t.float     "DecimalLatitude",                       :limit => 10
    t.float     "DecimalLongitude",                      :limit => 10
    t.text      "GeodeticDatum"
    t.float     "CoordinateUncertaintyInMeters"
    t.text      "DateLastModified"
    t.text      "InstitutionCode"
    t.text      "CollectionCode"
    t.text      "CatalogNumber"
    t.text      "ScientificName"
    t.text      "GlobalUniqueIdentifier"
    t.text      "InformationWithheld"
    t.text      "Remarks"
    t.text      "HigherTaxon"
    t.text      "Kingdom"
    t.text      "Phylum"
    t.text      "Class"
    t.text      "Order"
    t.text      "Family"
    t.text      "InfraspecificRank"
    t.text      "InfraspecificEpithet"
    t.text      "AuthorYearOfScientificName"
    t.text      "NomenclaturalCode"
    t.text      "IdentificationQualifer"
    t.text      "HigherGeography"
    t.text      "Continent"
    t.text      "WaterBody"
    t.text      "IslandGroup"
    t.text      "Island"
    t.text      "Country"
    t.text      "StateProvince"
    t.text      "County"
    t.text      "Locality"
    t.float     "MinimumElevationInMeters"
    t.float     "MaximumElevationInMeters"
    t.float     "MinimumDepthInMeters"
    t.float     "MaximumDepthInMeters"
    t.text      "CollectingMethod"
    t.boolean   "ValidDistributionFlag"
    t.text      "EarliestDateCollected"
    t.text      "LatestDateCollected"
    t.integer   "DayOfYear"
    t.integer   "MonthCollected"
    t.integer   "DayCollected"
    t.text      "Collector"
    t.text      "Sex"
    t.text      "LifeStage"
    t.text      "Attributes"
    t.text      "ImageURL"
    t.text      "RelatedInformation"
    t.float     "CatalogNumberNumeric"
    t.text      "IdentifiedBy"
    t.text      "DateIdentified"
    t.text      "CollectorNumber"
    t.text      "FieldNumber"
    t.text      "FieldNotes"
    t.text      "VerbatimCollectingDate"
    t.text      "VerbatimElevation"
    t.text      "VerbatimDepth"
    t.text      "Preparations"
    t.text      "TypeStatus"
    t.text      "GenBankNumber"
    t.text      "OtherCatalogNumbers"
    t.text      "RelatedCatalogedItems"
    t.text      "Disposition"
    t.integer   "IndividualCount"
    t.float     "PointRadiusSpatialFit"
    t.text      "VerbatimCoordinates"
    t.text      "VerbatimLatitude"
    t.text      "VerbatimLongitude"
    t.text      "VerbatimCoordinateSystem"
    t.text      "GeoreferenceProtocol"
    t.text      "GeoreferenceSources"
    t.text      "GeoreferenceVerificationStatus"
    t.text      "GeoreferenceRemarks"
    t.text      "FootprintWKT"
    t.float     "FootprintSpatialFit"
    t.text      "VerbatimSpecies"
    t.text      "AcceptedSpecies"
    t.text      "AcceptedNomenclaturalCode"
    t.text      "AcceptedKingdom"
    t.text      "AcceptedPhylum"
    t.text      "AcceptedClass"
    t.text      "AcceptedOrder"
    t.text      "AcceptedSuborder"
    t.text      "AcceptedFamily"
    t.text      "AcceptedSubfamily"
    t.text      "AcceptedGenus"
    t.text      "AcceptedSubgenus"
    t.text      "AcceptedSpecificEpithet"
    t.float     "DecLatInWGS84",                         :limit => 10
    t.float     "DecLongInWGS84",                        :limit => 10
    t.integer   "AdjustedCoordinateUncertaintyInMeters"
    t.float     "DEMElevation"
    t.float     "EtpTotal2000"
    t.float     "EtpTotalfuture"
    t.float     "EtpTotal1950"
    t.float     "GeolStrech"
    t.float     "MaxPerc2000"
    t.float     "MaxPercfuture"
    t.float     "MaxPerc1950"
    t.float     "MaxTemp2000"
    t.float     "MaxTempfuture"
    t.float     "Maxtemp1950"
    t.float     "MinPerc2000"
    t.float     "MinPercfuture"
    t.float     "MinPerc1950"
    t.float     "MinTemp2000"
    t.float     "MinTempfuture"
    t.float     "MinTemp1950"
    t.float     "PFC1950"
    t.float     "PFC1970"
    t.float     "PFC1990"
    t.float     "PFC2000"
    t.float     "RealMar2000"
    t.float     "RealMarfuture"
    t.float     "RealMar1950"
    t.float     "RealMat2000"
    t.float     "RealMatfuture"
    t.float     "RealMat1950"
    t.float     "WBPos2000"
    t.float     "WBPosfuture"
    t.float     "WBPos1950"
    t.float     "WBYear2000"
    t.float     "WBYearfuture"
    t.float     "WBYear1950"
    t.timestamp "LastUpdated",                                                             :null => false
    t.timestamp "TimeCreated",                                                             :null => false
    t.boolean   "Obfuscated",                                           :default => false
    t.text      "SharedUsers"
    t.boolean   "EmailVisible",                                         :default => true,  :null => false
    t.boolean   "reviewed"
    t.boolean   "stability"
  end

  create_table "record_review", :force => true do |t|
    t.integer  "userId",        :null => false
    t.integer  "occurrenceId",  :null => false
    t.boolean  "reviewed"
    t.datetime "reviewed_date"
  end

  create_table "taxonomic_reviewer", :force => true do |t|
    t.integer "userId",         :null => false
    t.string  "taxonomicField", :null => false
    t.string  "taxonomicValue", :null => false
  end

  create_table "taxonomy", :primary_key => "ID", :force => true do |t|
    t.float    "TA_ID"
    t.float    "ID_ACCEPTED"
    t.string   "NomenclaturalCode"
    t.string   "Kingdom"
    t.string   "KingdomSource"
    t.string   "Phylum"
    t.string   "PhylumSource"
    t.string   "SubPhylum"
    t.string   "SubPhylumSource"
    t.string   "Class"
    t.string   "ClassSource"
    t.string   "Subclass"
    t.string   "SubclassSource"
    t.string   "SuperOrder"
    t.string   "SuperOrderSource"
    t.string   "Order"
    t.string   "OrderSource"
    t.string   "Suborder"
    t.string   "SuborderSource"
    t.string   "InfraOrder"
    t.string   "InfraOrderSource"
    t.string   "SuperFamily"
    t.string   "SuperfamilySource"
    t.string   "Family"
    t.string   "FamilySource"
    t.string   "Subfamily"
    t.string   "SubfamilySource"
    t.string   "Genus"
    t.string   "GenusSource"
    t.string   "Subgenus"
    t.string   "SubgenusSource"
    t.string   "SpecificEpithet"
    t.string   "SpecificEpithetSource"
    t.string   "InfraspecificRank"
    t.string   "InfraspecificEpithet"
    t.string   "InfraspecificEpithetSource"
    t.string   "AcceptedSpecies"
    t.string   "VerbatimSpecies"
    t.string   "VerbatimSpeciesSource"
    t.float    "IsMarine"
    t.float    "IsTerrestrial"
    t.string   "Comments"
    t.string   "ReviewedBy"
    t.string   "ReviewDate"
    t.string   "Notes"
    t.string   "Status"
    t.string   "ChangedBy"
    t.datetime "ChangeDate"
    t.string   "Validation"
    t.string   "ValidatedBy"
    t.datetime "ValidationDate"
    t.float    "Stability"
  end

  add_index "taxonomy", ["Kingdom"], :name => "king_idx"
  add_index "taxonomy", ["Phylum"], :name => "phy_idx"

end
