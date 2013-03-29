require ARGV[0] #rails_environment
require 'logger'
require 'fileutils'
require 'csv'
require 'zipruby'

# modules
require_relative 'modules/model_utilities'
require_relative 'modules/env_utilities'
require_relative 'modules/general_utilities'
require_relative 'modules/csv_writer2'
require_relative 'modules/maxent'

#
# SETUP:
# Gets properties from properties file, start logging
#
##
fn = File.dirname(File.expand_path(__FILE__)) + '/yml/properties.yml'
props = YAML::load(File.open(fn))
log = Logger.new(props['logs'] + "LOG_" + Time.now.to_s.gsub(" ","_") + ".txt")
# Set rails env allowing different target databases, e.g. dev || prod
Rails.env = props['rails_environment']
GeneralUtilities.puts_log("Set rails environment to " + Rails.env, log)

# 
# STEP 1
# Read taxonomic authority
##
tax_hash = ModelUtilities.make_taxonomy_hash(props['taxonomic_authority_path'])
GeneralUtilities.puts_log("Reading taxonomic authority. Total species in TA: " + tax_hash.size.to_s, log)
species_count = GeneralUtilities.count_species(tax_hash)
if (species_count["mar_spp"] == 0 and props['marine'] == true)
  msg = "No marine species found in taxonomic authority. Check configuration. Program will exit..."
  abort(msg); log.error msg
end
msg = species_count["mar_spp"] > 0 ? " and " + species_count["mar_spp"].to_s + " marine" : ""
GeneralUtilities.puts_log("Found " + species_count["terr_spp"].to_s + " terrestrial" + msg + " species in TA", log)

#
# STEP 2:
# Create terrestrial mask array from all validated species
# This is used for bias masking when creating SWD
#
##
GeneralUtilities.puts_log("Reading database...", log)
if props['mask_read'] == true # use saved mask
  GeneralUtilities.puts_log("Reading terrestrial mask and years from ascii...", log)
  mask = GeneralUtilities.read_ascii(props['mask_path'] + props['mask_file'], props['terr_grid']['headlines'], props['terr_grid']['nrows'], props['terr_grid']['xll'], props['terr_grid']['yll'], props['terr_grid']['cell'])
  years = GeneralUtilities.read_years(props['mask_path'] + props['years_file'])
else # create new masks
  GeneralUtilities.puts_log("Creating new terrestrial mask from valid records...", log)
  # regular full run... 
  case props['mask_run_type'] 
  when 0
    # Regular full mask for production run. note AR doesn't understand alias_attribute
    mask_names = Occurrence.select("AcceptedSpecies").where(:validated => true).group("AcceptedSpecies")
  when 1
    # To get mask for smaller set (reviewed only - not the normal procedure for mask)
    # Generally only for testing or debugging!
    mask_names = Occurrence.select("AcceptedSpecies").where(:reviewed => true).group("AcceptedSpecies")
  when 2
    # To get mask for very small set
    # Generally only for testing or debugging!
    mask_names = Occurrence.where("AcceptedSpecies = 'Plagiolepis alluaudi'").group("AcceptedSpecies")
  end
  old_perc = 0
  not_found = [] # holds rescue cases
  cellids_years = []
  mask_cellid_array = [] # will hold cellid and occ, not destroyed each loop
  mask_names.each_with_index {|m, i|
    begin
      next if tax_hash[m.AcceptedSpecies][1] == "1" # skip this species if marine, e.g. IsMarine == true
      mask_raw = Occurrence.where(:validated => true).where("AcceptedSpecies = '#{m.AcceptedSpecies}'")
      mask_raw.each {|maskocc| # each valid occurrence
        lat = maskocc.DecimalLatitude
        long = maskocc.DecimalLongitude
        year = maskocc.YearCollected
        cellid = ModelUtilities.get_cellid(lat, long, props['terr_grid']['cell'], props['terr_grid']['xll'], props['terr_grid']['yll'], props['terr_grid']['nrows'], props['terr_grid']['ncols'], props['terr_grid']['headlines'])
        unless (cellid[1] > props['terr_grid']['nrows'] + props['terr_grid']['headlines'] or cellid[2] > props['terr_grid']['ncols']) # adds this unique value to every occurrence unless out of bounds
          mask_cellid_array << [cellid[0],maskocc]
          cellids_years << [cellid[0],year]
        end
      }
      old_perc = GeneralUtilities.print_progress(i,mask_names.size,old_perc)
    rescue
      not_found << m.AcceptedSpecies
      next
    end
  }
  GeneralUtilities.puts_log("\n",log)
  GeneralUtilities.puts_log(not_found.each{|missing| puts missing + " not found in taxonomy"}, log) unless not_found.nil? 
  GeneralUtilities.puts_log("Removing duplicate samples from mask...",log)
  # removes duplicates for mask and years
  mask = ModelUtilities.remove_grid_duplicates(mask_cellid_array)
  years = ModelUtilities.remove_years_by_cellid(cellids_years)
end

GeneralUtilities.puts_log("Terrestrial mask finished. Number of sampled cells: " + mask.size.to_s, log)
GeneralUtilities.puts_log("Total number of unique era-location records (from years array): " + years.size.to_s, log)

if props['mask_write'] == true
  GeneralUtilities.puts_log("Writing mask to ascii and years to csv for later use...", log)
  maskasc = GeneralUtilities.write_ascii(mask, props['terr_grid']['ncols'], props['terr_grid']['nrows'], props['terr_grid']['xll'], props['terr_grid']['yll'], props['terr_grid']['cell'], "-9999", props['mask_path'])
  GeneralUtilities.puts_log("Mask .asc: " + maskasc, log)
  yearsasc = GeneralUtilities.write_years(years, props['mask_path'])
  GeneralUtilities.puts_log("Years .csv: " + yearsasc,log)
end

#
# STEP 2B:
# Make Marine Mask
# Not doing sample bias masking for now. Just reading an ascii that represents the entire area
#
##
if props['marine'] == true
  GeneralUtilities.puts_log("Reading marine mask from ascii",log)
  marine_mask = GeneralUtilities.read_ascii(props['read_marine_ascii_mask_location'], props['marine_grid']['headlines'], props['marine_grid']['nrows'], props['marine_grid']['xll'], props['marine_grid']['yll'], props['marine_grid']['cell'])
  GeneralUtilities.puts_log("Marine mask finished. Number of cells in mask: " + marine_mask.size.to_s,log)
end

#
# STEP 3:
# Create array of reviewed records grouped by accepted species name
# This creates an array of names to iterate through and query for actual records, one name per iteration
# More scalable than getting all records at one time
#
##
GeneralUtilities.puts_log("Getting reviewed records...", log)
run_type = props['records_run_type']
case run_type
when 0
  # Regular full production run
  names = Occurrence.select("AcceptedSpecies").where(:reviewed => true).group("AcceptedSpecies")
when 1
  # To test one species/genera only for debugging
  #names = Occurrence.where(:acceptedspecies => "Tetraponera grandidieri").where(:reviewed => true).group("acceptedspecies")
  #names = Occurrence.where(:acceptedspecies => "Leptogenys arcirostris").where(:reviewed => true).group("acceptedspecies")
  names = Occurrence.where(:AcceptedOrder => "Primates").where(:reviewed => true).group("AcceptedSpecies")
  #names = Occurrence.where(:acceptedspecies => "Abudefduf vaigiensis").where(:reviewed => true).group("acceptedspecies")
  #names = Occurrence.where(:acceptedspecies => "Plectroglyphidodon johnstonianus").where(:reviewed => true).group("acceptedspecies")
end
#names_a = names.to_a
# This message makes no sense
# This is just a list of species with > 1 reviewed record, set up for the next step, when we actually get records
#GeneralUtilities.puts_log("Found " + names.to_a.size.to_s + " reviewed records", log)
names_size = names.to_a.size
GeneralUtilities.puts_log("Found " + names_size.to_s + " species with positively reviewed records", log)

#
# STEP 3.5
# TO DO: For now, if a species is marine then cannot be terr; 
#        this can be dealt with later, but will require using a mask to define realm
#        by occurrence location, rather than by acceptedspecies, as we are doing now

#
# STEP 4:
# Query for each species in the list of names built above
# 
##
msg = (props['marine'] == true ? "and marine " : "")
GeneralUtilities.puts_log("Removing duplicate records for terrestrial " + msg + "species...",log)
final_spp = []
old_perc = 0
names.each_with_index {|species,z|
  # Two queries, first to get positively reviewed public records:
  occ_raw_public = Occurrence.where(:reviewed => true).where("AcceptedSpecies = '#{species.AcceptedSpecies}'").where(:Public => true)
  # Second query to get positively reviewed private records that are "vettable" i.e. modelable
  occ_raw_private = Occurrence.where(:reviewed => true).where("AcceptedSpecies = '#{species.AcceptedSpecies}'").where(:Public => false).where(:Vettable => true)
  # Join the two result set arrays with simple '+', there is no overlap. results in array, not AR relation 
  occ_array = occ_raw_public + occ_raw_private

  # Remove duplicates by grid cell
  # For terrestrial species, need to consider era, forest and location (by cell) in definition of "duplicate"
  # Note: after 2013 update of Worldclim, there is no longer a 1950 "era", so duplicate is now only defined by forest at date collected, and location
  # For marine species, duplication is defined by grid cell only
  if occ_array.size >= props['minrecs'] # check size just for now, need to check again after removing dupes
    # first get cellid for each occurrance
    occ_cellid_array = [] # will hold cellid and occ, destroyed each loop
    occ_array.each {|occ|
      lat = occ.DecimalLatitude
      long = occ.DecimalLongitude
      year = occ.YearCollected
      name = occ.AcceptedSpecies

      # Assigns realm based on marine value. By default,
      # a species that is marine and terr will be assigned to marine
      # also, a species with no assignment in TA will be assigned terr
      realm = tax_hash[name][1] == "1" ? "marine" : "terrestrial"
      
      case realm
      when "terrestrial"
        skip = false
        cellid = ModelUtilities.get_cellid(lat, long, props['terr_grid']['cell'], props['terr_grid']['xll'], props['terr_grid']['yll'], props['terr_grid']['nrows'], props['terr_grid']['ncols'], props['terr_grid']['headlines'])
        # clim_era = year < 1975 ? 1950 : 2000 # assigns clim_era to 1950 for recs < 1975; 2000 for the rest
        # note: new worldclim no longer includes 1950, so no distinction here, no longer use "clim_era"
        for_era = EnvUtilities.get_forest_era(year, props)
        for_val = EnvUtilities.get_value(for_era, props, cellid[1], cellid[2])
        if for_val.nil?
          GeneralUtilities.puts_log("nil forest value for " + name + "(lat: " + lat.to_s + ", long: " + long.to_s + ")",log)  
          skip = true
        else 
          #uniq_val = cellid[0].to_s + "_&_" + clim_era.to_s + "_&_" + for_val.to_s # defines a uniq val by cellid, clim_era and forest value for deleting duplicates
          uniq_val = cellid[0].to_s + "_&_" + for_val.to_s # NEW defines a uniq val by cellid, and forest value for deleting duplicates
        end  
        # i[1] shows terr, marine; i[1] = [0,1] > mar; [1,1] > terr, mar; [1,0] > terr
      when "marine"
        next if props['marine'] == false # skip this spp if no marine run
        cellid = ModelUtilities.get_cellid(lat, long, props['marine_grid']['cell'], props['marine_grid']['xll'], props['marine_grid']['yll'], props['marine_grid']['nrows'], props['marine_grid']['ncols'], props['marine_grid']['headlines'])
        uniq_val = cellid
      end
      # Adds this unique value to every occurrence. This will be used to find and delete duplicates
      # terr dupes by definition depend on forest cover value AND location
      # marine duplicates are simply those that occur in same cell
      occ_cellid_array << [uniq_val,cellid,occ] unless skip == true 
    }
    single_sp = ModelUtilities.remove_grid_duplicates(occ_cellid_array)
    #msg = "..." + i.acceptedspecies + ": " + single_sp_arry.size.to_s + " records after removing duplicates"
    final_spp << single_sp if single_sp.size >= props['minrecs'] # looks like [[cellid,occ],[cellid,occ],[cellid,occ]]
  else
    #msg = i.acceptedspecies + ": Not enough records to model (" + occ_array.size.to_s + " records total)"
  end
  old_perc = GeneralUtilities.print_progress(z,names_size,old_perc)
}

#
# STEP 5:
# Progress report
#
##
GeneralUtilities.puts_log("\n",log)
GeneralUtilities.puts_log("Potential number of modelable species before removing grid duplicates: " + names_size.to_s,log)
GeneralUtilities.puts_log("Final number of modelable species after removing grid duplicates: " + final_spp.size.to_s,log)
if final_spp.size == 0
  msg = "No species to model. Program will exit..."
  abort(msg); log.error msg
end
GeneralUtilities.puts_log("Results after removing duplicates:", log)
for i in (0..final_spp.size - 1) do
  GeneralUtilities.puts_log(final_spp[i][0][2].AcceptedSpecies + " (" + final_spp[i].size.to_s + ")",log)
end

#
# STEP 6:
# Create one terr and one marine background SWD for use in all MaxEnt runs in this session
# 
##
if props['use_existing_background']['value'] == false # create new background
  msg = props['marine'] == true ? "terrestrial and marine" : "terrestrial" 
  GeneralUtilities.puts_log("Creating background SWDs for " + msg + " scenarios...", log)
  terr_backfile = ModelUtilities.create_background_swd(years, mask, props, props['env_layers'], props['trainingdir'] + "background_terr.swd", false)
  mar_backfile = true # allows to continue with no marine models 
  if props['marine'] == true
    mar_backfile = ModelUtilities.create_background_swd(nil, marine_mask, props, props['marine_layers'], props['trainingdir'] + "background_marine.swd", true)
  end
  if (terr_backfile and mar_backfile)
    GeneralUtilities.puts_log("\nBackground SWDs ok: true",log)
  else
    msg = "Error creating background swd's"
    abort(msg); log.error msg
  end
else # use existing background files named in properties.yml
  GeneralUtilities.puts_log("Using existing background SWDs from previous run.",log)
  #terr_backfile = []
  terr_backfile = props['use_existing_background']['terrestrial_file'] #string points to csv file, name assumed to match props['scen1'] below
  #backfiles << props['use_existing_background']['file2'] #string points to csv file, assumed to match props['scen2'] below
  mar_backfile = props['use_existing_background']['marine_file'] if props['marine'] == true # string points to marine background swd file
end

#
# STEP 6b:
# Delete entries in ascii model table if props['global_run'] == true
##
# First delete all existing records from AscModel table
# This assumes a global model run from scratch; not appending to existing set of models!
AscModel.delete_all if props['delete_ascii_model_records'] # deletes all existing records in AscModel table (in db set in database.yml)

#
# STEP 7:
# Create sample SWDs for each species, add these file locations to list
# note:  this is start of long model loop for each species
#        the reasoning here is that other methods that deal with all spp at once
#        require huge arrays of occurrences, etc., will not scale to 10000's spp
##
for j in (0..final_spp.size - 1) do #every species
  # Note: final_spp[j] = each species (final_spp[j].size = total records for that species]
  #       final_spp[j][x] = one record array for one spp [uniq_val,cellid,occ]
  #       final_spp[j][x][2] = one occurrence
  GeneralUtilities.puts_log(GeneralUtilities.dash(100),log)
  GeneralUtilities.puts_log("Starting model for " + final_spp[j][0][2].AcceptedSpecies.split(" ").join("_"),log)
  GeneralUtilities.puts_log(GeneralUtilities.dash(100),log)
  # additional setup:
  project_ok = false # looks for at least one successful projection for each species

  # One sample swd method for terr, another for marine
  realm = tax_hash[final_spp[j][0][2].AcceptedSpecies][1] == "1" ? "marine" : "terrestrial"
  # Notes: marine swd with samples is not really needed here becuase this is not used below
  #        given that there is no marine projection (for now)
  #files = realm == "marine" ? ModelUtilities.create_marine_sample_swd(final_spp[j],props) : ModelUtilities.create_sample_swd(final_spp[j],props)
  case realm
  when "terrestrial"
    files = ModelUtilities.create_sample_swd(final_spp[j],props,props['env_layers'],false)
  when "marine"
    files = ModelUtilities.create_sample_swd(final_spp[j],props,props['marine_layers'],true)  
  end 
  name = files["name"]
  final_count = files["count"]
  GeneralUtilities.puts_log("Number of records start: " + final_spp[j].size.to_s, log)
  GeneralUtilities.puts_log("Number of records after making SWD and removing records with NODATA for environmental values: " + final_count.to_s, log)
  if final_count < props['minrecs']
    GeneralUtilities.puts_log("Not enough records to model. Moving to next species...",log)
    next
  else
    GeneralUtilities.puts_log("Done sample SWD for species " + name,log)
  end

  #
  # Step 7a. Run Maxent (model training)
  #
  ##
  terr_model, marine_model = nil
  GeneralUtilities.puts_log("Starting MaxEnt...",log)
  replicates = (final_count >= props['replicates']['sample_threshold'] ? props['replicates']['reps_above'] : props['replicates']['reps_below'])
  args = ["replicates=" + replicates.to_s, "replicatetype=crossvalidate", "redoifexists", "nowarnings", "novisible", "threads=" + props['threads_arg'].to_s, "extrapolate=" + props['extrapolate'].to_s, "autorun"]
  density = "density.MaxEnt"
  to_validate = {}
  invalid = true
  case realm
  when "terrestrial"
    output = props['trainingdir'] + name + "_" + props['scen_name1'] + File::SEPARATOR
    GeneralUtilities.rm_mkdir(output)
    #Debug# puts "Params: " + props['maxent_path'] + ", " + backfiles[0] + ", " + props['trainingdir'] + name + "_" + props['scen_name1'] + "_swd.csv"  + ", " + output
    samples = props['trainingdir'] + name + "_swd.csv"
    terr_model = Maxent.run_maxent(props['maxent_path'], props['memory_arg'], output, args, :density=>density, :lambdas=>samples, :background=>terr_backfile)
    if terr_model
      to_validate["model"] = props['scen_name1']
      to_validate["output"] = output
      invalid = false
    end
    GeneralUtilities.puts_log(name + " " + props['scen_name1'] + "_model success: " + terr_model.to_s, log)
  when "marine"
    output = props['trainingdir'] + name + "_marine" + File::SEPARATOR
    GeneralUtilities.rm_mkdir(output)
    samples = props['trainingdir'] + name + "_" + "marine_swd.csv"
    marine_model = Maxent.run_maxent(props['maxent_path'], props['memory_arg'], output, args, :density=>density, :lambdas=>samples, :background=>mar_backfile)
    if marine_model
      GeneralUtilities.puts_log(name + " marine_model success: " + marine_model.to_s, log)
      to_validate["model"] = "marine"
      to_validate["output"] = output
      invalid = false
    end
  end

  #
  # Step 7b. Validate Maxent result (terr and marine)
  #
  ##
  validated = ModelUtilities.validate_result(to_validate["output"], replicates)
  validated["model"] = to_validate["model"]

  if validated == [] # Some big maxent error here, expected information not found in maxentResults.csv
    validated["validity"] = false # force to false
    invalid = true
  else
    GeneralUtilities.puts_log(GeneralUtilities.dash(80) + "\n" + name + " " + validated["model"] + " VALIDITY TEST:" + "\n" + GeneralUtilities.dash(80), log)
    GeneralUtilities.puts_log("Mean AUC: " + validated["mean_auc"].to_s + "\nStandard error: " + validated["standard_error"].to_s + "\nValidity: " + validated["value"].to_s, log)
    GeneralUtilities.puts_log(name + " " + validated["model"] + " valid: " + validated["validity"].to_s + "\n" + GeneralUtilities.dash(80), log)
  end

  if invalid # NO valid models
    GeneralUtilities.puts_log("NO valid model for " + name + "...", log)
  else # a valid model
    #
    # Step 7c. Create full Maxent model(s) if at least one valid result
    #          Note: Not producing full marine model now, because cannot project
    #          to grids that are the same that produced the lambda; rather, for marine we
    #          use Maxent.density.MaxEnt to "project" to grids without replication
    ##
    next if validated == nil or validated["validity"] == false # necessary??
    if validated["validity"] # true=valid, then create full model
      output = props['trainingdir'] + name + "_" + validated["model"] + "_full" + File::SEPARATOR
      GeneralUtilities.rm_mkdir(output)
      case validated["model"]
      when props['scen_name1']
        background_file = terr_backfile
        samples = props['trainingdir'] + name + "_swd.csv"
      when "marine"
        background_file = mar_backfile
        samples = props['trainingdir'] + name + "_" + validated["model"] + "_swd.csv"
        next # can change this later if we end up with multiple marine scenarioss to project to
               # for now, next just skips any marine models. Full model is produced in "projection" below
      end
      #samples = props['trainingdir'] + name + "_" + v["model"].sub + "_swd.csv"
      #puts samples
      args = ["redoifexists", "nowarnings", "novisible", "threads=" + props['threads_arg'].to_s, "extrapolate=" + props['extrapolate'].to_s, "autorun"]
      full_model = Maxent.run_maxent(props['maxent_path'], props['memory_arg'], output, args, :density=>density, :lambdas=>samples, :background=>background_file)
      GeneralUtilities.puts_log(name + " " + validated["model"] + "_full FULL model success: " + full_model.to_s, log)
    else
        # TO DO Delete model testing stuff -- to save space
        # here or at end, after copy html etc.?
    end
  end # at least one valid model

  #
  # Run Maxent projections from full model lambdas
  #
  ##
  GeneralUtilities.puts_log("Projecting...", log)
  newdir = props['outputdir'] + name
  GeneralUtilities.rm_mkdir(newdir)

  terrestrial_scenarios = terr_model == true ? props['terrestrial_scenarios'].split(",") : nil
  marine_scenario = marine_model == true ? ["marine"] : nil # only one single marine projection (for now)
  [terrestrial_scenarios, marine_scenario].each_with_index {|scenarios, i|
    case i
    when 0 
      scenario_type = props['scen_name1']
      density = "density.Project"
      lambda = props['trainingdir'] + name + "_" + scenario_type + "_full" + File::SEPARATOR + name + ".lambdas"
      args = [nil]
    when 1
      scenario_type = "marine"
      density = "density.MaxEnt"
      lambda = props['trainingdir'] + name + "_" + "marine_swd.csv" # not lambdas, actually samples here
      args = ["responsecurves redoifexists nowarnings novisible autorun threads=" + props['threads_arg'].to_s]
    end
    next if scenarios == nil
    scenarios.each {|scenario|
      output = props['outputdir'] + name + File::SEPARATOR + scenario + File::SEPARATOR
      #puts "out: " + out
      grids = props['link_path'] + scenario + File::SEPARATOR
      GeneralUtilities.rm_mkdir(output)
      # need an actual ascii file name
      outputname = scenario_type == "marine" ? output : output + name + ".asc" # switch needed for density.Project
      project_ok = Maxent.run_maxent(props['maxent_path'], props['memory_arg'], outputname, args, :density=>density, :lambdas=>lambda, :background=>grids)
      if project_ok
        outputname = outputname + name + ".asc" if scenario_type == "marine" # switch output to asc name for zipping
        new = EnvUtilities.fix_asc(outputname, props['terr_grid']['headlines'])
        File.delete(outputname)
        File.rename(new, outputname)

        #
        # Add documentation, metadata, public samples to output folders and zip
        #
        ##
        # Copies MaxEnt html from Full model to new output folder
        if scenario_type != "marine"
          html = props['trainingdir'] + name + "_" + scenario_type + "_full" + File::SEPARATOR + name + ".html"
          ModelUtilities.fix_html(html, name)
          ModelUtilities.copy_results(name, output, scenario_type, html, props)
        end

        # Zip each scenario
        ModelUtilities.zip_first(name, scenario, outputname, output, props)
        GeneralUtilities.puts_log("Created " + scenario + " projection for " + name + ": " + project_ok.to_s, log)
      end # project_ok
      if project_ok == false
        GeneralUtilities.puts_log("Projection failed for " + name + ", scenario: " + scenario, log)
      end
    } # scenario
  } # scenarios

  #
  # Write occurrences to occurrence csv (one per species)
  #
  ##
  if project_ok
    occ_array = files["occ_array"]
    priv_array = files["priv_array"]
    skip_fields = ["Owner"] # include any fields here to exclude from CSV
    col_names = Occurrence.column_names
    csv_occ_file = CsvWriter2.write_csv(occ_array, props['outputdir'] + name + File::SEPARATOR + name + "_occurrences.csv", col_names, skip_fields)

    # Write citation file (one per species)
    GeneralUtilities.write_citation(name, final_count, priv_array, props)

    # Zip each species
    zipfile = props['outputdir'] + name + '.zip'
    FileUtils.rm(zipfile) if FileTest::file?(zipfile)
    Zip::Archive.open(zipfile, Zip::CREATE) do |archive|
      archive.add_file(csv_occ_file.path)
      archive.add_file(props['outputdir'] + name + File::SEPARATOR + "citation.txt")
    end

    [terrestrial_scenarios, marine_scenario].each_with_index {|scenarios, i|
      next if scenarios == nil
      scenarios.each {|scenario|
        Zip::Archive.open(zipfile, Zip::CREATE) do |archive|
          archive.add_file(props['outputdir'] + name + File::SEPARATOR + scenario + '.zip')
        end
      }
    }

    #
    # Write details to ascii table
    #
    ##
    #msg = "Writing results to asc_models database table..."
    ModelUtilities.asc_table_add(name)
    GeneralUtilities.puts_log("Finished models for " + name + " (" + (j + 1).to_s + " of " + final_spp.size.to_s + " species total)", log)
  else
    GeneralUtilities.puts_log("No valid projections for " + name + "...", log)
  end # at least one validated full model
  GeneralUtilities.puts_log(GeneralUtilities.dash(80), log)
end #each species

# Optionally change ownership of files created during run
if props['chown']
  GeneralUtilities.puts_log("Changing model ownership...", log)
  Dir.glob(props['trainingdir'] + '**/*').each {|f| File.chown props['owner_uid'], props['owner_uid'], f}
  Dir.glob(props['outputdir'] + '**/*').each {|e| File.chown props['owner_uid2'], props['owner_uid2'], e}
end

# Optionally copy output to Models path on tomcat
if props['move_to_tomcat']
  if props['delete_old_tomcat']
    GeneralUtilities.puts_log("Deleting existing models from tomcat directory: " + props['models_path'], log)
    FileUtils.rm_r props['models_path']
    FileUtils.mkdir props['models_path']
  end
  # Copy files to tomcat, either as links or files
  # Instead of copying all files, copy directory structure, and symbolic links to files
  #   enables storage of one copy - note however need to create new outputdir each time
  #   if for any reason you want to keep old models, and supplement with new ones as opposed
  #   to regenerating all models every time
  GeneralUtilities.puts_log("Copying new models to Tomcat...", log)
  Dir.glob(props['outputdir'] + '**/*').each {|f|
    if File.directory?(f)
      FileUtils.mkdir_p(props['models_path'] + f.sub(props['outputdir'],""))
    else
      if props['links'] # copy links to files only
        FileUtils.ln_s(f, props['models_path'] + f.sub(props['outputdir'], ""), :force => true)
      else # copy full files
        FileUtils.cp_r props['outputdir'] + '/.', props['models_path']
      end
    end
  }

  # Change ownership (not relevant for links, but ok)
  Dir.glob(props['models_path'] + '**/*').each {|e| File.chown props['owner_uid2'], props['owner_uid2'], e} if props['chown']
  GeneralUtilities.puts_log("Changing model ownership...", log) if props['chown']
end

GeneralUtilities.puts_log("Model Manager complete.", log)

