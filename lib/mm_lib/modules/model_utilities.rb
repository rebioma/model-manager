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

  # Removes duplicates from an array of any dimension, 
  # based on the uniqueness of the first element
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
  # Create  background swd for marine or terrestrial scenarios
  # 
  def ModelUtilities.create_background_swd(years, mask, props, layers, filename, marine)
    env_layers = layers.split(",")
    backfile = File.new(filename, "w")
    head = []
    head << "name" << "longitude" << "latitude"
    env_layers.each {|h| head << h }
    head << "pfc" if marine == false
    backfile.puts(head.join(","))
    # calculate proportions of years per era for terrestrial background
    proportions = GeneralUtilities.eras_proportions(years) if marine == false
    old_perc = 0
    case marine
    when false # terr
      proportions.each_with_index{|prop, p| #iterate through each year in the proportion it was sampled
        # limit is the number of samples times the proportion
        # multiplied across proportions, this totals the n samples
        limit = (prop[1].to_f * props['background_samples'].to_f).round
        limit = 1 if limit == 0 # avoids 0..-1 in following step for proportions == 0
        (0..(limit - 1)).each do
          occ = mask[rand(mask.size)][1] # Gets the occurrence part of the mask array
          cellid = ModelUtilities.get_cellid(occ.DecimalLatitude, occ.DecimalLongitude, props['terr_grid']['cell'], props['terr_grid']['xll'], props['terr_grid']['yll'], props['terr_grid']['nrows'], props['terr_grid']['ncols'], props['terr_grid']['headlines'])
          era = prop[0]
          line, nodata = ModelUtilities.get_swd_line(env_layers, marine, props, occ.DecimalLongitude, occ.DecimalLatitude, cellid, era, "background")
          redo if nodata == true # if nodata anywhere in line don't write line, don't inc counter, redo random draw
          backfile.puts(line.join(",")) 
        end
        old_perc = GeneralUtilities.print_progress(p,proportions.size,old_perc)
      }
    when true # marine
      (0..(props['background_samples'] - 1)).each_with_index do |n, p|
        occ = mask[rand(mask.size)][1] # Gets the occurrence part of the mask array
        cellid = ModelUtilities.get_cellid(occ.DecimalLatitude, occ.DecimalLongitude, props['marine_grid']['cell'], props['marine_grid']['xll'], props['marine_grid']['yll'], props['marine_grid']['nrows'], props['marine_grid']['ncols'], props['marine_grid']['headlines'])
        line, nodata = ModelUtilities.get_swd_line(env_layers, marine, props, occ.DecimalLongitude, occ.DecimalLatitude, cellid, nil, "background")
        redo if nodata # if nodata anywhere in line don't write line, don't inc counter, redo random draw
        backfile.puts(line.join(",")) 
        old_perc = GeneralUtilities.print_progress(p,props['background_samples'],old_perc)
      end
    end
    GeneralUtilities.flush_and_close([backfile])
    return filename
  end

  # method to construct one line of background and lookup env values for terr and marine spp
  def ModelUtilities.get_swd_line(layers, marine, props, long, lat, cellid, era, name)
    line = []
    line << name << long << lat
    # lookup clim values
    nodata = false
    layers.each {|layer|
      ourlayer = marine ? layer : layer.sub(".asc","_2000.asc")
      aval = EnvUtilities.get_value(ourlayer, props['env_path'], cellid[1], cellid[2])
      line << aval # Note: aval is returned as string with 7 decimal places
      nodata = true if (aval.to_i == -9999 or aval == nil)
    }
    if marine == false
      for_layer = EnvUtilities.get_forest_ascii(era, props)
      fval = EnvUtilities.get_value(for_layer, props['env_path'], cellid[1], cellid[2])
      line << fval
    end
    return [line, nodata]    
  end

  ##
  # Creates sample SWD from an array of occurrences for one marine species: (species)
  # species[n] is one occurrence array, consisting of n=[uniq_val,[cellid_array],occ]
  # species[n][1] is the cellid, for looking up env vals; cellid is an array of [cellid, getrow, getcol]
  # species[n][2] is the occurrence itself
  # THIS ONE INCLUDES ENV VALUES NEEDED FOR SWD FOR PROJECTION
  def ModelUtilities.create_sample_swd(species, props, layers, marine)
    # Setup and open files
    env_layers = layers.split(",")
    occ_array, priv_array, head = [], [], [] # to hold occurrences for csv output, and a counter for private records

    names = (species[0][2].AcceptedSpecies).split(" ") # get name from first record
    name = names.join("_") # puts name into format for SWD
    msg = "Starting model for " + name; puts msg#; log.info msg
    head << "name" << "longitude" << "latitude"
    env_layers.each {|layer_name| head << layer_name }
    head << "pfc" if marine == false
    
    fileid = marine ? "_marine_swd.csv" : "_swd.csv"
    afile = File.new(props['trainingdir'] + name + fileid, "w") # No forest scenario
    afile.puts(head.join(","))

    # Create sample SWD for one species
    count = 0
    for z in (0..species.size - 1) do #every cellid-occurrence array
      cellid = species[z][1]
      occ = species[z][2]
      if occ.Public == true
        occ_array << occ #only public records into occ_array
      else
        occ.EmailVisible ? priv_array << occ.email : priv_array << "email not provided"
      end
      era = EnvUtilities.get_era(occ.YearCollected)
      line, nodata = ModelUtilities.get_swd_line(env_layers, false, props, occ.DecimalLongitude, occ.DecimalLatitude, cellid, era, name)
      next if nodata == true
      afile.puts(line.join(",")) 
      count += 1
    end
    GeneralUtilities.flush_and_close([afile])
    files = {"name"=> name, "acceptedspecies" => species[0][2].AcceptedSpecies, "swd_file"=> afile, "occ_array" => occ_array, "priv_array" => priv_array, "count" => count}
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
    maxent_result_csv = File.open(indir + "maxentResults.csv", "_")
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