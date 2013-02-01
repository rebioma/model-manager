require ARGV[0] #rails_environment
require 'logger'
require 'fileutils'
require 'csv'

# modules
require_relative 'modules/model_utilities'
require_relative 'modules/env_utilities'
require_relative 'modules/db_utilities'
require_relative 'modules/general_utilities'
require_relative 'modules/csv_writer2'

#
# SETUP:
# Get properties from properties file, start logging
#
##
fn = File.dirname(File.expand_path(__FILE__)) + '/yml/properties.yml'
props = YAML::load(File.open(fn))
log = Logger.new(props['logs'] + "LOG_" + Time.now.to_s.gsub(" ","_") + ".txt")

# 
# STEP 1
# Read taxonomic authority
##
tax_hash = ModelUtilities.make_taxonomy_hash(props['taxonomic_authority_path'])
GeneralUtilities.puts_log("Reading taxonomic authority. Number of species in TA: " + tax_hash.size.to_s, log)
terr_spp = 0; mar_spp = 0
i = 0
tax_hash.each {|key|
  terr_spp += 1 if key.last[0] == "1"
  mar_spp += 1 if key.last[1] == "1"
}
if (mar_spp == 0 and props['marine'] == true)
  msg = "No marine species found in taxonomic authority. Check configuration. Program will exit..."
  abort(msg); log.error msg
end
msg = mar_spp > 0 ? " and " + mar_spp.to_s + " marine" : ""
GeneralUtilities.puts_log("Found " + terr_spp.to_s + " terrestrial" + msg + " species in TA", log)

#
# STEP 2:
# Create terrestrial mask array from all validated species
# This is used for bias masking when creating SWD
#
##
msg =  "Reading database..."; puts msg; log.info msg
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
  not_found = []
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
      perc = ((i + 1).to_f/mask_names.size.to_f) * 100
      progress = GeneralUtilities.get_progress(old_perc,perc)
      print progress if (progress.nil? == false)
      old_perc = perc
    rescue
      not_found << m.AcceptedSpecies
      next
    end
  }
  GeneralUtilities.puts_log("\n",log)
  GeneralUtilities.puts_log(not_found.each{|missing| puts missing + " not found in taxonomy"}, log) unless not_found.nil? 
  GeneralUtilities.puts_log("Removing duplicate samples from mask...",log)
  mask = ModelUtilities.remove_grid_duplicates(mask_cellid_array)
  years = ModelUtilities.remove_years_by_cellid(cellids_years)
end

msg = "Terrestrial mask finished. Number of sampled cells: " + mask.size.to_s; puts msg; log.info msg
msg = "Total number of unique era-location records (from years array): " + years.size.to_s; puts msg; log.info msg

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
  #occ_array_pub = occ_raw_public.to_a
  #occ_array_priv = occ_raw_private.to_a
  # Join the two result set arrays with simple '+', there is no overlap. results in array, not AR relation 
  occ_array = occ_raw_public + occ_raw_private

  # Remove duplicates by grid cell
  # For terrestrial species, need to consider era, forest and location (by cell) in definition of "duplicate"
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
      # a species that is marine and terr will be assigned marine
      # also, a species with no assignment in TA will be assigned terr
      realm = tax_hash[name][1] == "1" ? "marine" : "terrestrial"
      
      case realm
      when "terrestrial"
        skip = false
        cellid = ModelUtilities.get_cellid(lat, long, props['terr_grid']['cell'], props['terr_grid']['xll'], props['terr_grid']['yll'], props['terr_grid']['nrows'], props['terr_grid']['ncols'], props['terr_grid']['headlines'])
        clim_era = year < 1975 ? 1950 : 2000 # assigns clim_era to 1950 for recs < 1975; 2000 for the rest
        for_era = EnvUtilities.get_forest_era(year, props['forest_eras'])
        for_val = EnvUtilities.get_value(for_era, props['env_path'], cellid[1], cellid[2])
        if for_val.nil?
          GeneralUtilities.puts_log("nil forest value for " + name + "(lat: " + lat.to_s + ", long: " + long.to_s + ")",log)  
          skip = true
        else 
          uniq_val = cellid[0].to_s + "_&_" + clim_era.to_s + "_&_" + for_val.to_s # defines a uniq val by cellid, clim_era and forest value for deleting duplicates
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

  perc = ((z + 1).to_f/names_size.to_f) * 100
  progress = GeneralUtilities.get_progress(old_perc,perc)
  print progress if (progress.nil? == false)
  old_perc = perc
}

#
# STEP 5:
# Progress report
#
##
GeneralUtilities.puts_log("Potential n modelable spp before removing grid duplicates: " + names_size.to_s,log)
GeneralUtilities.puts_log("Final n modelable spp after removing grid duplicates: " + final_spp.size.to_s,log)
if final_spp.size == 0
  msg = "No species to model. Program will exit..."
  abort(msg); log.error msg
end
msg = "Results after removing duplicates:"; puts msg; log.info msg
for i in (0..final_spp.size - 1) do
  GeneralUtilities.puts_log(final_spp[i][0][2].AcceptedSpecies + " (" + final_spp[i].size.to_s + ")",log)
end

Process.exit

#
# STEP 6:
# Create one terr and one marine background SWD for use in all MaxEnt runs in this session
# TO DO: Need marine background SWD also? Yes but simple derivation, random within entire area
##
msg = "Creating background SWDs..."; puts msg; log.info msg
if props['use_existing_background']['value'] == false
  msg = "Creating background SWDs for climate, climate/forest and marine scenarios..."; puts msg; log.info msg
  backfiles = ModelUtilities.create_background_swd(years, mask)
  mar_backfile = true # allows no marine models 
  if props['marine'] == true
    mar_backfile = ModelUtilities.create_marine_background_swd(marine_mask)
  end
  if (backfiles and mar_backfile)
    msg = "\nBackground SWDs ok: true"; puts msg; log.info msg
  else
    msg = "Error creating background swd's"
    abort(msg); log.error msg
  end
else # use existing background files named in properties.yml
  msg = "Using existing background SWDs from previous run..."; puts msg; log.info msg
  backfiles = []
  backfiles << props['use_existing_background']['file1'] #string points to csv file, name assumed to match props['scen1'] below
  backfiles << props['use_existing_background']['file2'] #string points to csv file, assumed to match props['scen2'] below
  mar_backfile = props['use_existing_background']['marine_file'] if props['marine'] == true # string points to marine background swd file
end

#
# STEP 6b:
# Delete entries in ascii model table if true
##
# First delete all existing records from AscModel table
# This assumes a global model run from scratch; not appending to existing set here!
AscModel.delete_all if props['global_run'] # deletes all existing records in AscModel table (rebioma_mm)

#
# STEP 7:
# Create sample SWDs for each species, add these file locations to list
# TO DO: this is start of long model loop for each species
#        the reasoning here is that other methods that deal with all spp at once
#        require huge arrays of occurrences, etc., will not scale to 10000's spp
##
for j in (0..final_spp.size - 1) do #every species
  # Note: final_spp[j] = each species (final_spp[j].size = total records for that species]
  #       final_spp[j][x] = one record array for one spp [uniq_val,cellid,occ]
  #       final_spp[j][x][2] = one occurrence
  # additional setup:
  good_proj = false # looks for at least one successful projection for each species

  # One sample swd method for terr, another for marine
  realm = tax_hash[final_spp[j][0][2].acceptedspecies][1] == "1" ? "marine" : "terrestrial"
  # TO DO: add messaging here or inside create_swd
  # Notes: marine swd with samples is not really needed here becuase this is not used below
  #        given that there is no marine projection (for now)
  #        really all that is needed for marine is name,lat,long - could speed this up TO DO, new method
  files = realm == "marine" ? ModelUtilities.create_marine_sample_swd(final_spp[j]) : ModelUtilities.create_sample_swd(final_spp[j])
  name = files["name"]
  final_count = files["count"]
  msg = "Number of records start: " + final_spp[j].size.to_s; puts msg; log.info msg
  msg = "Number of records after making SWD and removing records with NODATA for environmental values: " + final_count.to_s; puts msg; log.info msg
  if final_count < props['minrecs']
    msg = "Not enough records to model. Moving to next species..."; puts msg; log.info msg
    next
  else
    msg = "Done sample SWD for species " + name; puts msg; log.info msg
  end
  #
  # Step 7a. Run Maxent (model training)
  #
  ##
  climfor_model, climonly_model, marine_model = nil
  msg = "Starting MaxEnt..."; puts msg; log.info msg
  replicates = (final_count >= props['replicates']['sample_threshold'] ? props['replicates']['reps_above'] : props['replicates']['reps_below'])
  args = ["replicates=" + replicates.to_s, "replicatetype=crossvalidate", "redoifexists", "nowarnings", "novisible", "threads=" + props['threads_arg'].to_s, "extrapolate=" + props['extrapolate'].to_s, "autorun"]
  validate = []
  invalid = true
  case realm
  when "terrestrial"
    output = props['trainingdir'] + name + "_" + props['scen_name1'] + File::SEPARATOR
    output2 = props['trainingdir'] + name + "_" + props['scen_name2'] + File::SEPARATOR
    [output, output2].each do |out|
      FileUtils.rm_rf(out) if FileTest::directory?(out)
      Dir::mkdir(out)
    end
    #puts "Params: " + props['maxent_path'] + ", " + backfiles[0] + ", " + props['trainingdir'] + name + "_" + props['scen_name1'] + "_swd.csv"  + ", " + output
    climonly_model = ModelUtilities.run_maxent(props['maxent_path'], backfiles[0], props['trainingdir'] + name + "_" + props['scen_name1'] + "_swd.csv", output, args, props['memory_arg'])
    climfor_model = ModelUtilities.run_maxent(props['maxent_path'], backfiles[1], props['trainingdir'] + name + "_" + props['scen_name2'] + "_swd.csv", output2, args, props['memory_arg'])
    if climonly_model
      msg = name + " " + props['scen_name1'] + "_model success: " + climonly_model.to_s; puts msg; log.info msg
      validate << {"model" => props['scen_name1'], "output" => output }
      invalid = false
    else
      msg = name + " " + props['scen_name1'] + "_model success: " + climonly_model.to_s; puts msg; log.info msg
    end
    if climfor_model
      msg = name + " " + props['scen_name2'] + "_model success: " + climfor_model.to_s; puts msg; log.info msg
      validate << {"model" => props['scen_name2'], "output" => output2 }
      invalid = false
    else
      msg = name + " " + props['scen_name2'] + "_model success: " + climonly_model.to_s; puts msg; log.info msg
    end
  when "marine"
    output3 = props['trainingdir'] + name + "_marine" + File::SEPARATOR
    FileUtils.rm_rf(output3) if FileTest::directory?(output3)
    Dir::mkdir(output3)
    marine_model = ModelUtilities.run_maxent(props['maxent_path'], mar_backfile, props['trainingdir'] + name + "_" + "marine_swd.csv", output3, args, props['memory_arg'])
    if marine_model
      msg = name + " marine_model success: " + marine_model.to_s; puts msg; log.info msg
      validate << {"model" => "marine", "output" => output3 }
      invalid = false
    end
  end

  #
  # Step 7b. Validate Maxent result (terr and marine)
  #
  ##
  validated = []
  validate.each {|model_result|
    v = {}
    v = ModelUtilities.validate_result(model_result["output"], replicates)
    v["model"] = model_result["model"]
    validated << v
  }

  validated.each {|v|
    if v == [] # Some big maxent error here, expected information not found in maxentResults.csv
      v["validity"] = false # force to false
      invalid = true
    else
      msg = GeneralUtilities.dash(80) + "\n" + name + " " + v["model"] + " VALIDITY TEST:" + "\n" + GeneralUtilities.dash(80); puts msg; log.info msg
      msg = "Mean AUC: " + v["mean_auc"].to_s + "\nStandard error: " + v["standard_error"].to_s + "\nValidity: " + v["value"].to_s; puts msg; log.info msg
      msg = name + " " + v["model"] + " valid: " + v["validity"].to_s + "\n" + GeneralUtilities.dash(80); puts msg; log.info msg
    end
  }

  if invalid # NO valid models
    msg = "NO valid models for " + name + "..."; puts msg; log.error msg
  else # At least one valid model
    #
    # Step 7c. Create full Maxent model(s) if at least one valid result
    #          Note: Not producing full marine model now, because cannot project
    #          to grids that are the same that produced the lambda; rather, for marine we
    #          use Maxent.density.MaxEnt to "project" to grids without replication
    ##
    validated.each do |v|
      next if v == nil or v["validity"] == false
      if v["validity"] # true=valid, then create full climonly model
        args = ["redoifexists", "nowarnings", "novisible", "threads=" + props['threads_arg'].to_s, "extrapolate=" + props['extrapolate'].to_s, "autorun"]
        output = props['trainingdir'] + name + "_" + v["model"] + "_full" + File::SEPARATOR
        FileUtils.rm_rf(output) if FileTest::directory?(output)
        Dir::mkdir(output) unless v["model"] == "marine"
        case v["model"]
        when props['scen_name1']
          background_file = backfiles[0]
        when props['scen_name2']
          background_file = backfiles[1]
        when "marine"
          background_file = mar_backfile
          next # can change this later if we end up with multiple marine scenarioss to project to
               # for now, next just skips any marine models. Full model is produced in "projection" below
        end
        #samples = props['trainingdir'] + name + "_" + v["model"].sub + "_swd.csv"
        #puts samples
        s = ModelUtilities.run_maxent(props['maxent_path'], background_file, props['trainingdir'] + name + "_" + v["model"] + "_swd.csv", output, args, props['memory_arg'])
        msg = name + " " + v["model"] + "_full FULL model success: " + s.to_s; puts msg; log.info msg
      else
        # TO DO Delete model testing stuff -- to save space
        # here or at end, after copy html etc.?
      end
    end
  end # at least one valid model

  #
  # Run Maxent projections from full model lambdas
  #
  ##
  msg = "Projecting..."; puts msg; log.info msg
  newdir = props['outputdir'] + name
  FileUtils.rm_rf(newdir) if FileTest::directory?(newdir)
  Dir::mkdir(newdir)

  climate_scenarios = climonly_model == true ? props['climate_scenarios'].split(",") : nil
  forest_scenarios = climfor_model == true ? props['forest_scenarios'].split(",") : nil
  marine_scenario = marine_model == true ? ["marine"] : nil # only one single marine projection (for now)
  [climate_scenarios, forest_scenarios, marine_scenario].each_with_index {|scenarios, i|
    case i
    when 0
      scenario_type = props['scen_name1']
      density = "density.Project"
      lambda = props['trainingdir'] + name + "_" + scenario_type + "_full" + File::SEPARATOR + name + ".lambdas"
      args = ""
    when 1
      scenario_type = props['scen_name2']
      density = "density.Project"
      lambda = props['trainingdir'] + name + "_" + scenario_type + "_full" + File::SEPARATOR + name + ".lambdas"
      args = ""
    when 2
      scenario_type = "marine"
      density = "density.MaxEnt"
      lambda = props['trainingdir'] + name + "_" + "marine_swd.csv" # not lambdas, actually samples here
      args = "responsecurves redoifexists nowarnings novisible autorun threads=" + props['threads_arg'].to_s
      #puts args
    end
    next if scenarios == nil
    scenarios.each {|scenario|
      output = props['outputdir'] + name + File::SEPARATOR + scenario + File::SEPARATOR
      #puts "out: " + out
      grids = props['link_path'] + scenario + File::SEPARATOR
      FileUtils.rm_rf(output) if FileTest::directory?(output) # make output directory
      Dir::mkdir(output)
      # need an actual ascii file name
      outputname = scenario_type == "marine" ? output : output + name + ".asc" # switch needed for density.Project
      project_ok = ModelUtilities.run_maxent_density(props['maxent_path'], props['memory_arg'], lambda, grids, outputname, args, density)
      good_proj = true if project_ok
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
          # fix for weird link in this file to .csv file, instead of ascii:
          # (perhaps a MaxEnt 3.3.3e bug? when using density.Project, not a problem with marine (density.Maxent)
          FileUtils.cp(html,html + "_cp") # copy the orig
          html_file = File.open(html + "_cp") # open the copy
          FileUtils.rm(html) # delete the old one
          html_str = html_file.read
          html_str.sub(name + ".csv", name + ".asc") # change the ref from csv to asc. Note this only replaces first occurrence
          html_new = File.new(html,"w") # make an empty file
          html_new.write(html_str)
          html_new.close
          html_file.close
          #csv = props['trainingdir'] + name + "_" + scenario_type + "_full" + File::SEPARATOR + name + ".csv"
          lambda = props['trainingdir'] + name + "_" + scenario_type + "_full" + File::SEPARATOR + name + ".lambdas"
          omission = props['trainingdir'] + name + "_" + scenario_type + "_full" + File::SEPARATOR + name + "_omission.csv"
          predictions = props['trainingdir'] + name + "_" + scenario_type + "_full" + File::SEPARATOR + name + "_samplePredictions.csv"
          results = props['trainingdir'] + name + "_" + scenario_type + "_full" + File::SEPARATOR + "maxentResults.csv"
          plots_dir = props['trainingdir'] + name + "_" + scenario_type + "_full" + File::SEPARATOR + "plots" + File::SEPARATOR
          FileUtils.cp(html, output + name + ".html")
          #FileUtils.cp(csv, output + name + ".csv") # this includes private data, not clear what it is anyway
          FileUtils.cp(lambda, output + name + ".lambdas")
          FileUtils.cp(omission, output + name + "_omission.csv")
          FileUtils.cp(predictions, output + name + "_samplePredictions.csv")
          FileUtils.cp(results, output + "maxentResults.csv")
          FileUtils.cp_r(plots_dir, output + "plots")
        end

        # Zip each scenario
        Zip::Archive.open(props['outputdir'] + name + File::SEPARATOR + scenario + '.zip', Zip::CREATE) do |archive|
          archive.add_file(outputname)
          archive.add_file(output + name + ".html")
          #archive.add_file(output + name + ".csv") if scenario_type != "marine" # this includes private data, not clear what it is anyway
          archive.add_file(output + name + ".lambdas")
          archive.add_file(output + name + "_omission.csv")
          archive.add_file(output + name + "_samplePredictions.csv")
          archive.add_file(output + "maxentResults.csv")
          archive.add_dir("plots")
          a = props['outputdir'] + name + File::SEPARATOR + scenario + File::SEPARATOR + "plots" + File::SEPARATOR
          pngs = Dir.glob(a + '*.png')
          pngs.each {|png|
            archive.add_file("plots" + File::SEPARATOR + File.basename(png), png)
          }
          #archive.add_file("plots" + File::SEPARATOR + name + "_roc.png", output + "plots" + File::SEPARATOR + name + "_roc.png")
        end
        msg = "Created " + scenario + " projection for " + name + ": " + project_ok.to_s; puts msg; log.info msg
      end # project_ok
      if project_ok == false
        msg = "Projection failed for " + name + ", scenario: " + scenario; puts msg; log.error msg
      end
    } # scenario
  } # scenarios

  #
  # Write occurrences to occurrence csv (one per species)
  #
  ##
  if good_proj
    occ_array = files["occ_array"]
    priv_array = files["priv_array"]
    skip_fields = ["Owner"] # include any fields here to exclude from CSV
    col_names = Occurrence.column_names
    csv_occ_file = CsvWriter2.write_csv(occ_array, props['outputdir'] + name + File::SEPARATOR + name + "_occurrences.csv", col_names, skip_fields)
    #
    # Write citation file (one per species)
    #
    ##
    cite_file = File.new(props['outputdir'] + name + File::SEPARATOR + "citation.txt","w")
    source_file = File.open("citation.template.txt","r")
    source_lines = source_file.readlines

    i = 0
    source_lines.each {|line|
      line = line.sub("zzz", final_spp[j][0][2].acceptedspecies) if i == 0
      line = line.sub("zzz", Time.now.to_s) if i == 1
      line = line.sub("zzz", final_count.to_s) if i == 3
      line = line.sub("zzz", priv_array.size.to_s) if i == 4
      if i == 5
        if priv_array.size == 0
          i += 1
          next
        else # get private data emails
             ## TO DO: Don't do this, these are private
          a_props = []
          priv_array.uniq.sort_by{|x|priv_array.grep(x)}.each{|x| a_props << [x, priv_array.grep(x).size]}
          zz = []
          a_props.each {|ee| zz << ee.join(" (") }
          line = line.sub("zzz", zz.join("), ") + ")")
         #line = line.sub("zzz", priv_array.sort.uniq.join(", "))
        end
      end
      line = line.sub("zzz", name + "_occurrences.csv") if i == 7
      line = line.sub("zzz", Time.now.year.to_s) if i == 10
      line = line.sub("zzz", GeneralUtilities.get_month_name(Time.now.month) + " " + Time.now.day.to_s + ", " + Time.now.year.to_s) if i == 12
      cite_file.puts(line.gsub(/\n/, "\r\n"))
      #puts line + ", " + i.to_s
      i += 1
    }

    cite_file.flush
    cite_file.close

    # Zip each species
    zipfile = props['outputdir'] + name + '.zip'
    FileUtils.rm(zipfile) if FileTest::file?(zipfile)
    Zip::Archive.open(zipfile, Zip::CREATE) do |archive|
      archive.add_file(csv_occ_file.path)
      archive.add_file(props['outputdir'] + name + File::SEPARATOR + "citation.txt")
    end

    [climate_scenarios, forest_scenarios, marine_scenario].each_with_index {|scenarios, i|
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
    msg = "Finished models for " + name + " (" + (j + 1).to_s + " of " + final_spp.size.to_s + " species total)"; puts msg; log.info msg
  else
    msg = "No valid projections for " + name + "..."; puts msg; log.error msg
  end # at least one validated full model
  msg = GeneralUtilities.dash(80) + "\n" + GeneralUtilities.dash(80); puts msg; log.info msg
end #each species

# Final to do:
# 5) Delete bash scripts and any other temp/extraneous files TO DO (see above, del. temp training)
# especially delete training models to save space

#
# Replaces production models table with results of model runs
## Note: This is a change to the production database and server; may want to be careful as this will
## throw existing users off. Also may require restarting tomcat for changes to work online
if props['replace_ascii_db']
  final_bash = DbUtilities.run_ascii_table_bash(props, db)
  msg = "Ascii model database table copied ok: " + final_bash.to_s; puts msg; log.info msg
end

# chown files created during run
if props['chown']
  msg = "Changing model ownership..."; puts msg; log.info msg
  Dir.glob(props['trainingdir'] + '**/*').each {|f| File.chown props['owner_uid'], props['owner_uid'], f}
  Dir.glob(props['outputdir'] + '**/*').each {|e| File.chown props['owner_uid2'], props['owner_uid2'], e}
end

# copy output to Models path on tomcat
if props['move_to_tomcat']
  if props['delete_old_tomcat']
    msg = "Deleting existing models from tomcat directory: " + props['models_path']; puts msg; log.info msg
    FileUtils.rm_r props['models_path']
    FileUtils.mkdir props['models_path']
  end
  # Copy files to tomcat, either as links or files
  # Instead of copying all files, copy directory structure, and symbolic links to files
  #   enables storage of one copy - note however need to create new outputdir each time
  #   if for any reason you want to keep old models, and supplement with new ones as opposed
  #   to regenerating all models every time
  msg = "Copying new models to Tomcat..."; puts msg; log.info msg
  Dir.glob(props['outputdir'] + '**/*').each {|f|
    if File.directory?(f)
      FileUtils.mkdir_p(props['models_path'] + f.sub(props['outputdir'],""))
    else
      if props['links'] # copy links
        FileUtils.ln_s(f, props['models_path'] + f.sub(props['outputdir'], ""), :force => true)
      else # copy full files
        FileUtils.cp_r props['outputdir'] + '/.', props['models_path']
      end
    end
  }

  # Change ownership (not relevant for links, but ok)
  Dir.glob(props['models_path'] + '**/*').each {|e| File.chown props['owner_uid2'], props['owner_uid2'], e} if props['chown']
  msg = "Changing model ownership..."; puts msg if props['chown']; log.info msg if props['chown']
end

msg = "Model Manager complete."; puts msg; log.info msg

