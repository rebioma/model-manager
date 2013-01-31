# To change this template, choose Tools | Templates
# and open the template in the editor.

module ModelUtilities

  def ModelUtilities.count_reviews(in_ary)
    # "Reviewed" in occurrences seems to refer to recs with sum positive review. Here checking on actual reviews in review table to make sure they sum to > 8. This is not probably necessary, but a safer way of getting only positively reviewed occurrences
    t = 0
    in_ary.each {|o| # in_ary here is an array of occurrences for one species, joined to reviews
      for z in 0..(o.reviews.count - 1) do # interesting that reviews association carries through
        if o.reviews[z].review == true
          t = t + 1 #counts number of true reviews for this species
                    #TO DO: What about multiple reviews (by diff reviewers)
                    # for ex you could have 1 occ with 8 pos reviews, what happens then?
                    # we want sum pos reviewed recs = 8 not sure that's what this does
        end
      end
    }
    return t
  end

  # Given an array of years and cellids [ [24,1980], [24,2001], [380,2008], [2345,2010] ]
  # removes duplicates by era and cellid combination, and returns list of years
  def ModelUtilities.remove_years_by_cellid(cellids_years)
    get_uniq = []
    final = []
    cellids_years.each {|id_year|
      cellid = id_year[0]
      year = id_year[1]
      era = EnvUtilities.get_era(year)
      combo = cellid.to_s + "_" + era.to_s
      get_uniq << [combo,year]
    }
    results = ModelUtilities.remove_grid_duplicates(get_uniq)
    results.each {|result| final << result[1]}
    return final
  end

  # Removes duplicates from an array of any dimension, based on the uniqueness of the first element
  def ModelUtilities.remove_grid_duplicates(in_array)
    keep = 9999
    deldup = []
    in_array2 = in_array.sort_by{|a| a[0]}
    in_array2.each_with_index{|z,i|
      if i == 0 # first time
        keep = z[0]
      else
        if z[0] == keep
          deldup << i
        end
        keep = z[0]
      end
    }
    # delete them based on index in deldup
    ndel = 0
    deldup.sort!
    deldup.each {|d|
      in_array2.delete_at(d - ndel)
      ndel += 1
    }
    return in_array2
  end

  # Cellid is assigned to each cell in the grid, starting with 1 in the top left corner
  # and proceeding to n in the bottom right. For a grid with 3 rows and 6 cols, the bottom
  # right cell recieves a cellid = 18
  #
  # By contrast, getrow refers to the ascii grid file, and counts starting at line 0 from the
  # top of the file. For an ascii file with 6 header lines and 3 rows, a cell in the bottom row
  # has a getrow of 8. Getcol simply counts columns from left to right starting from 0.
  #
  # In sum, an x,y in bottom right cell of a 3 row by 6 col ascii grid with 6 header lines returns
  # [18, 8, 5]
  ##
  def ModelUtilities.get_cellid(lat, long, cell, xll, yll, nrows, ncols, headlines)
    longcol = (((long - xll)/cell).to_int)
    getcol = longcol # counting from 0, as we will in the array from this line
    latrow = (((lat - yll)/cell).to_int) #counting from bottom row = 0
    getrow = nrows - latrow + (headlines - 1) # get this line from file counting from 0
    llid = ((nrows - 1) * ncols) + 1 #counting from left col = 0
    cellid = llid + longcol - (ncols * latrow)
    return cellid, getrow, getcol # NOTE headlines offset built into getrow
  end

  def ModelUtilities.get_random_occurrence(xll, yll, cell, nrows, ncols, layerfile, env_path, offset)
    val = -9999
    getcol = 0
    getrow = 0
    # runs until landing on a non-null grid cell
    until val != -9999
      getcol = rand(ncols)
      getrow = rand(nrows) + offset
      val = (EnvUtilities.get_value(layerfile, env_path, getrow, getcol)).to_f
    end
    # gets lat long for this path row
    #puts "val " + val.to_s
    #puts "getcol " + getcol.to_s
    #puts "getrow " + getrow.to_s
    latlong = ModelUtilities.get_latlong(xll, yll, cell, getrow, getcol, nrows, offset)
    #puts "lat " + latlong[0].to_s
    #puts "long " + latlong[1].to_s
    occ = NewOccurrence.new("background",latlong[0],latlong[1])
    return occ
  end

  def ModelUtilities.get_latlong(xll, yll, cell, getrow, getcol, nrows, headlines)
   #llid = ((nrows - 1) * ncols) + 1
   ll_center_x = xll + (cell * 0.5)
   ll_center_y = yll + (cell * 0.5)
   long = ll_center_x + (getcol * cell)
   #lat = ll_center_y + (getrow * cell) #(getrow - nrows - headlines) * cell + yll = (lat - yll)/cell)
   lat = ll_center_y + ((nrows - getrow + (headlines - 1)) * cell)
   return [lat, long]
  end

  #
  # Create terrestrial background swd for two scenarios
  #
  def ModelUtilities.create_background_swd(years, mask)
    props = YAML.load_file("properties.yml")
    clim1950 = props['clim_era_layers'][1950].split(",")
    clim2000 = props['clim_era_layers'][2000].split(",")
    files = [props['trainingdir'] + props['scen_name1'] + "_background.swd",props['trainingdir'] + props['scen_name2'] + "_background.swd",props['trainingdir'] + "background_" + props['scen_name2'] + "_swd_LOG.csv"]
    backfile = File.new(files[0], "w") # No forest background swd
    backfile2 = File.new(files[1], "w") # With forest background swd
    backlog2 = File.new(files[2], "w")

    head = []
    head << "name" << "longitude" << "latitude"
    clim1950.each {|h|
      head << h.sub("_50.asc","")
      }
    backfile.puts(head.join(","))
    head << "pfc"
    backfile2.puts(head.join(","))
    # OLD head << "year" << "era" << "prop[1]" << "type"
    head << "year" << "era" << "prop[1]"
    backlog2.puts(head.join(","))
    proportions = GeneralUtilities.eras_proportions(years)
    # To check that proportions sum to 1.0:
    # a = 0; proportions.each{|b| a = a + b[1]}; puts a
    #puts proportions

    proportions_size = proportions.size
    old_perc = 0
    proportions.each_with_index{|prop, p| #iterate through each year in the proportion it was sampled
      count = 1
      # limit is the number of samples times the proportion
      # multiplied across proportions, this totals the n samples
      limit = (prop[1].to_f * props['background_samples'].to_f).round
      limit = 1 if limit == 0
      # limit2 is number of samples in the mask times the era proportion
      # only used in original conception, where samples are taken randomly under mask until count of mask exceeded, then taken randomly anywhere
      # limit2 = (prop[1].to_f * mask.size.to_f).round + 1
      (0..(limit - 1)).each do 
        line = []
        # ex. mask = [ [[1],["occ"]], [[2],["occ"]], [[3],["occ"]] ]
        # New method, does not take into account mask size. Background selected ONLY from mask regardless
        occ = mask[rand(mask.size)][1] # Gets the occurrence part of the mask array
        # Old method, background initially selected under mask, then randomly after limit2
        #count <= limit2 ? occ = mask[rand(mask.size)][1] : occ = ModelUtilities.get_random_occurrence(props['terr_grid']['xll'], props['terr_grid']['yll'], props['terr_grid']['cell'], props['terr_grid']['nrows'], props['terr_grid']['ncols'], props['for_era_layers'][1950], props['env_path'], props['terr_grid']['headlines']) # ternary choice get vals from masked cells, from random when mask cells "used up"
        # UNCOMMENT to select all background randomly (without consideration of sample mask)
        #occ = ModelUtilities.get_random_occurrence(props['terr_grid']['xll'], props['terr_grid']['yll'], props['terr_grid']['cell'], props['terr_grid']['nrows'], props['terr_grid']['ncols'], props['for_era_layers'][1950], props['env_path'], props['terr_grid']['headlines'])

        lat = occ.decimallatitude
        long = occ.decimallongitude
        cellid = ModelUtilities.get_cellid(lat, long, props['terr_grid']['cell'], props['terr_grid']['xll'], props['terr_grid']['yll'], props['terr_grid']['nrows'], props['terr_grid']['ncols'], props['terr_grid']['headlines'])

        line << "background" << long << lat
        era = prop[0]
        clims = era < 3 ? clim1950 : clim2000 # assigns clim_era to 1950 for recs < 1975; 2000 for the rest
        
        # lookup clim values
        nodata = false
        clims.each {|clayer|
          aval = EnvUtilities.get_value(clayer, props['env_path'], cellid[1], cellid[2])
          line << aval # Note: aval is returned as string with 7 decimal places
          nodata = true if (aval == "-9999.0000000" or aval == nil)
        }
        redo if nodata == true # if nodata anywhere in line don't write line, don't inc counter, redo random draw
        backfile.puts(line.join(",")) # No forest
        for_era = EnvUtilities.get_forest_ascii(era)
        fval = EnvUtilities.get_value(for_era, props['env_path'], cellid[1], cellid[2])
        line << fval
        backfile2.puts(line.join(",")) # plus forest for forest background scenario
        year = EnvUtilities.get_year(era)
        # old check on mask/random limit
        #line << year << era << prop[1] << (count <= limit2 ? "mask" : "random")
        line << year << era << prop[1]
        backlog2.puts(line.join(","))
        count += 1
      end
      perc = ((p + 1).to_f/proportions_size.to_f) * 100
      progress = GeneralUtilities.get_progress(old_perc,perc)
      print progress if progress.nil? == false
      old_perc = perc
    }
    backfile.flush
    backfile2.flush
    backfile.close
    backfile2.close
    backlog2.flush
    backlog2.close
    return files
  end

  def ModelUtilities.create_marine_background_swd(marine_mask)
    props = YAML.load_file("properties.yml")
    marlayers = props['marine_layers'].split(",")
    backfile = File.new(props['trainingdir'] + "background_marine.swd", "w") # marine background file
    head = []
    head << "name" << "longitude" << "latitude"
    marlayers.each {|h|
      head << h
      }
    backfile.puts(head.join(",")) # writes header to output
    old_perc = 0
    (0..(props['background_samples'] - 1)).each_with_index do |n, p|
      line = []
      # ex. mask = [ [[1],["occ"]], [[2],["occ"]], [[3],["occ"]] ]
      occ = marine_mask[rand(marine_mask.size)][1] # Gets the occurrence part of the mask array
      # UNCOMMENT to select all background randomly (without consideration of sample mask)
      #occ = ModelUtilities.get_random_occurrence(props['terr_grid']['xll'], props['terr_grid']['yll'], props['terr_grid']['cell'], props['terr_grid']['nrows'], props['terr_grid']['ncols'], props['for_era_layers'][1950], props['env_path'], props['terr_grid']['headlines'])

      lat = occ.decimallatitude
      long = occ.decimallongitude
      cellid = ModelUtilities.get_cellid(lat, long, props['marine_grid']['cell'], props['marine_grid']['xll'], props['marine_grid']['yll'], props['marine_grid']['nrows'], props['marine_grid']['ncols'], props['marine_grid']['headlines'])

      line << "background" << long << lat

      # lookup clim values
      nodata = false
      marlayers.each {|clayer|
        aval = EnvUtilities.get_value(clayer, props['env_path'], cellid[1], cellid[2])
        line << aval # Note: aval is returned as string with 7 decimal places
        nodata = true if (aval == "-9999.0000000" or aval == nil)
      }
      redo if nodata == true # if nodata anywhere in line don't write line, don't inc counter, redo random draw
      backfile.puts(line.join(",")) # No forest
      perc = ((p + 1).to_f/props['background_samples'].to_f) * 100
      progress = GeneralUtilities.get_progress(old_perc,perc)
      print progress if progress.nil? == false
      old_perc = perc
    end

    backfile.flush
    backfile.close

    return backfile
  end

  ##
  # Creates sample SWD from an array of occurrences for one marine species: (species)
  # species[n] is one occurrence array, consisting of n=[uniq_val,[cellid_array],occ]
  # species[n][1] is the cellid, for looking up env vals; cellid is an array of [cellid, getrow, getcol]
  # species[n][2] is the occurrence itself
  # THIS ONE DOES NOT LOOK UP ENV VALUES! SINCE WE ARE NOT PROJECTING< ONLY NEED LAT-LONG
  def ModelUtilities.create_marine_sample_swd2(species)
    # no scenarios, NO ENV VALUES; just get cellid and lookup lat-long
    props = YAML.load_file("properties.yml")
    occ_array = [] # to hold occurrences for csv output
    priv_array = [] # counter for private records
    names = (species[0][2].acceptedspecies).split(" ") # get name from first record
    name = names.join("_") # puts name into format for SWD
    puts "Starting marine model for " + name

    head = []
    head << "name" << "longitude" << "latitude"
    afile = File.new(props['trainingdir'] + name + "_marine_swd.csv", "w") # marine
    afile.puts(head.join(","))

    #
    # Create sample SWD for one species
    #
    ##
    count = 0
    for z in (0..species.size - 1) do #every cellid-occurrence array
      line = []
      cellid = species[z][1]
      occ = species[z][2]
      if occ.public_record == true
        occ_array << occ
      else
        occ.email_visible ? priv_array << occ.email : priv_array << "email not provided"
      end
      line << name << occ.decimallongitude << occ.decimallatitude
      afile.puts(line.join(",")) # Write single line
      count += 1
    end
    afile.flush
    afile.close
    files = {"name"=> name, "acceptedspecies" => species[0][2].acceptedspecies, "mar_swd_file"=> afile, "occ_array" => occ_array, "priv_array" => priv_array, "count" => count}
    return files # hash with name and mar_swd_file
  end

    ##
  # Creates sample SWD from an array of occurrences for one marine species: (species)
  # species[n] is one occurrence array, consisting of n=[uniq_val,[cellid_array],occ]
  # species[n][1] is the cellid, for looking up env vals; cellid is an array of [cellid, getrow, getcol]
  # species[n][2] is the occurrence itself
  # THIS ONE INCLUDES ENV VALUES NEEDED FOR SWD FOR PROJECTION
  def ModelUtilities.create_marine_sample_swd(species)
    # no scenarios, just get cellid and lookup env values
    props = YAML.load_file("properties.yml")
    mar_layers = props['marine_layers'].split(",")
    occ_array = [] # to hold occurrences for csv output
    priv_array = [] # counter for private records
    names = (species[0][2].acceptedspecies).split(" ") # get name from first record
    name = names.join("_") # puts name into format for SWD
    puts "Starting marine model for " + name

    head = []
    head << "name" << "longitude" << "latitude"
    mar_layers.each {|h|
      head << h
      }
    afile = File.new(props['trainingdir'] + name + "_marine_swd.csv", "w") # marine
    afile.puts(head.join(","))

    #
    # Create sample SWD for one species
    #
    ##
    count = 0
    for z in (0..species.size - 1) do #every cellid-occurrence array
      line = []
      cellid = species[z][1]
      occ = species[z][2]
      if occ.public_record == true
        occ_array << occ
      else
        occ.email_visible ? priv_array << occ.email : priv_array << "email not provided"
      end
      line << name << occ.decimallongitude << occ.decimallatitude
      # lookup clim values
      nodata = false
      mar_layers.each {|clayer|
        aval = EnvUtilities.get_value(clayer, props['env_path'], cellid[1], cellid[2])
        line << aval
        nodata = true if (aval == "-9999.0000000" or aval == nil)
      }
      next if nodata == true
      afile.puts(line.join(",")) # Write single line
      count += 1
    end
    afile.flush
    afile.close
    files = {"name"=> name, "acceptedspecies" => species[0][2].acceptedspecies, "mar_swd_file"=> afile, "occ_array" => occ_array, "priv_array" => priv_array, "count" => count}
    return files # hash with name and mar_swd_file
  end


  ##
  # Creates sample SWD from an array of occurrences for one species: (species)
  # species[n] is one occurrence array, consisting of n=[uniq_val,cellid,occ]
  # species[n][1] is the cellid, for looking up env vals; cellid is an array of [cellid, getrow, getcol]
  # species[n][2] is the occurrence
  #
  def ModelUtilities.create_sample_swd(species)
    ##
    # Setup and open files
    #
    props = YAML.load_file("properties.yml")
    clim1950 = props['clim_era_layers'][1950].split(",")
    clim2000 = props['clim_era_layers'][2000].split(",")
    #for j in (0..final_spp.size - 1) do
    occ_array = [] # to hold occurrences for csv output
    priv_array = [] # counter for private records
    names = (species[0][2].acceptedspecies).split(" ") # get name from first record
    name = names.join("_") # puts name into format for SWD
    msg = "Starting model for " + name; puts msg#; log.info msg
    head = []
    head << "name" << "longitude" << "latitude"
    clim1950.each {|h|
      head << h.sub("_50.asc","")
      }
    afile = File.new(props['trainingdir'] + name + "_" + props['scen_name1'] + "_swd.csv", "w") # No forest scenario
    afile2 = File.new(props['trainingdir'] + name + "_" + props['scen_name2'] + "_swd.csv", "w") # with forest
    logfile = File.new(props['trainingdir'] + name + "_" + props['scen_name2'] + "_swd_LOG.csv", "w") # SWD log file
    afile.puts(head.join(","))
    head << "pfc"
    afile2.puts(head.join(","))
    head << "year"
    logfile.puts(head.join(","))

    #
    # Create sample SWD for one species
    #
    ##
    count = 0
    for z in (0..species.size - 1) do #every cellid-occurrence array
      line = []
      cellid = species[z][1]
      occ = species[z][2]
      if occ.public_record == true
        occ_array << occ #only public records into occ_array
      else
        occ.email_visible ? priv_array << occ.email : priv_array << "email not provided"
      end

      line << name << occ.decimallongitude << occ.decimallatitude
      year = occ.yearcollected
      clims = year < 1975 ? clim1950 : clim2000 # assigns clim_era to 1950 for recs < 1975; 2000 for the rest

      # lookup clim values
      nodata = false
      clims.each {|clayer|
        aval = EnvUtilities.get_value(clayer, props['env_path'], cellid[1], cellid[2])
        line << aval
        nodata = true if (aval == "-9999.0000000" or aval == nil)
      }
      next if nodata == true
      afile.puts(line.join(",")) # Write no forest line
      count += 1
      for_era = EnvUtilities.get_forest_era(year, props['forest_eras'])
      line << EnvUtilities.get_value(for_era, props['env_path'], cellid[1], cellid[2])
      afile2.puts(line.join(",")) # Write with forest line
      line << year
      logfile.puts(line.join(","))
    end
    afile.flush
    afile2.flush
    logfile.flush
    afile.close
    afile2.close
    logfile.close
    #files = [name, afile, afile2, logfile] # what about occ_array and priv_array??
    files = {"name"=> name, "climonly_swd_file"=> afile, "climfor_swd" => afile2, "logfile" => logfile, "occ_array" => occ_array, "priv_array" => priv_array, "count" => count}
    return files
  end

  def ModelUtilities.run_maxent(path, background, samples, output, args, mem)
    #props = YAML.load_file("properties.yml")
    #puts "java " + mem + " -jar " + path + " environmentallayers=" + background + " samplesfile=" + samples + " outputdirectory=" + output + " " + args.join(" ")
    javacmd = "java " + mem + " -jar " + path + " environmentallayers=" + background + " samplesfile=" + samples + " outputdirectory=" + output + " " + args.join(" ")
    success = system(javacmd)
    return success
  end

  def ModelUtilities.run_maxent_density(path, mem, lambdas_samples, grids, output, args, density)
    # lambdas_samples: lambdas if density.Project, samples if density.MaxEnt
    if density == "density.MaxEnt" # some additional props required
      output = "outputdirectory=" + output
      lambdas_samples = "samplesfile=" + lambdas_samples
      grids = "environmentallayers=" + grids
    end
    javacmd = "java " + mem + " -cp " + path + " " + density + " " + lambdas_samples + " " + grids + " " + output + " " + args
    #puts javacmd
    success = system(javacmd)
    return success
  end

  def ModelUtilities.run_maxent_density_project(path, lambdas, grids, output, mem)
    #props = YAML.load_file("properties.yml")
    javacmd = "java " + mem + " -cp " + path + " density.Project " + lambdas + " " + grids + " " + output
    #puts javacmd
    success = system(javacmd)
    return success
  end

  def ModelUtilities.run_maxent_density_maxent(path, args, output, samples, grids, mem)
    #java density.MaxEnt autorun redoifexists nowarnings noprefixes responsecurves outputdirectory=/home/tomay/mm/output/Zebrazoma_scopas samplesfile=/home/tomay/mm/training/Zebrazoma_scopas_marine_swd.csv environmentallayers=/home/tomay/mm/ascii_links/marine
    javacmd = "java " + mem + " -cp " + path + " density.MaxEnt " + args + " " + output + " " + samples + " "  + grids
    success = system(javacmd)
    return success
  end

  def ModelUtilities.validate_result(indir, replicates)
    maxent_result_csv = File.open(indir + "maxentResults.csv", "r")
    lines = maxent_result_csv.readlines
    header = lines[0].split(",")
    n = header.index("Training AUC")
    sum_training_auc = 0
    training_aucs = []
    (0..replicates).each{|e| # Last line in maxentResults.csv is average. Do not want this val
      line = lines[e]
      elements = line.split(",")
      sum_training_auc = sum_training_auc + elements[n].to_f if e > 0
      training_aucs << elements[n].to_f if e > 0
      }

    sdev = GeneralUtilities.standard_deviation(training_aucs)
    sqrt_runs = Math.sqrt(replicates)
    standard_error = sdev / sqrt_runs
    mean_auc = sum_training_auc / replicates
    validity = mean_auc - standard_error
    v = validity > 0.5 ? true : false
    return {"validity" => v, "mean_auc" => mean_auc, "standard_error" => standard_error, "value" => validity}
  end

  def ModelUtilities.asc_table_add(name)
    a = AscModel.where(:accepted_species => "name")
    if a.size == 0
      asc = AscModel.new
    else
      asc = a
    end
    asc.accepted_species = name.sub("_"," ")
    asc.model_location = name
    asc.index_file = name + ".html"
    asc.save
  end

  def ModelUtilities.make_taxonomy_hash(taxonomy)
    tax_hash = {}
    accepted_count = 0
    marine_count = 0
    terr_count = 0
    taxonomic_authority = File.open(taxonomy) #, 'r:windows-1251:utf-8') # this is a guess at encoding, and could really mess things up if incorrect
    ## read realms to memory. TO DO. When all is Ruby 1.9, can use built in CSV library
    taxonomic_authority.each_with_index{|line,i|
      #line.encode!('UTF-8', 'UTF-8') # deals with most invalid UTF-8 characters
      line = line.unpack('C*').pack('U*') if !line.valid_encoding? # deals with additional exceptions
      vals = line.gsub("\"","").strip.split(",") 
      if i == 0 # header
        vals.each_with_index{|val, count|
          accepted_count = count if val == "AcceptedSpecies"
          marine_count = count if val == "IsMarine"
          terr_count = count if val == "IsTerrestrial"
        }
      else # every line after header
        tax_hash[vals[accepted_count]] = [vals[terr_count],vals[marine_count]]
      end
    }
    return tax_hash
  end

  def ModelUtilities.make_taxonomy_hash_with_csv(taxonomy)
    tax_hash = {}
    CSV.foreach(taxonomy, :headers => true, :header_converters => :symbol, :converters => :all, :encoding => 'windows-1251:utf-8') do |row|
      a = row[:acceptedspecies]; b = row[:isterrestrial]; c = row[:ismarine]
      tax_hash[a] = [b, c]
    end
    return tax_hash  
  end

  def ModelUtilities.lookup_realm(names, taxonomy)
    realms = {}
    names_realms = []
    accepted_count = 0
    marine_count = 0
    terr_count = 0
    taxonomic_authority = File.open(taxonomy,"r")
    ## read realms to memory
    taxonomic_authority.each_with_index{|line,i|
      vals = line.strip.split(",")
      if i == 0 # header
        vals.each_with_index{|val, count|
          accepted_count = count if val == "AcceptedSpecies"
          marine_count = count if val == "IsMarine"
          terr_count = count if val == "IsTerrestrial"
        }
      else # every line after header
        realms[vals[accepted_count]] = [vals[terr_count],vals[marine_count]]
      end
    }
    
    ## lookup each name, append with realm from hash
    names.each {|name|
      realm_vals = realms[name.acceptedspecies]
      names_realms << [name, realm_vals]
    }

    return names_realms
  end

end

