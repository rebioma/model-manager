# To change this template, choose Tools | Templates
# and open the template in the editor.

module GeneralUtilities
  def GeneralUtilities.puts_log(msg, log)
    puts msg
    log.info msg
  end

  def GeneralUtilities.get_progress(min,max)
    prog = []
    a = min.to_i
    b = max.to_i
    prog << "0%" if min == 0
    diff = b - a
    if diff >= 1
      (a..b).each {|n|
        if (GeneralUtilities.multiple?(n,10))
          prog << n.to_s + "%" unless min.to_i == n
        elsif GeneralUtilities.multiple?(n,2)
          prog << "." unless min.to_i == n
        end
      }
    end
    progress = prog.join("")
    return progress
  end

  def GeneralUtilities.print_progress(i,obj_size,old_perc)
    perc = ((i + 1).to_f/obj_size.to_f) * 100
    progress = GeneralUtilities.get_progress(old_perc,perc)
    print progress if (progress.nil? == false)
    return perc
  end

  def GeneralUtilities.dash(n)
    dash = "-"
    (1..n).each{ dash += "-" }
    return dash
  end

  def GeneralUtilities.multiple?(x, multiple)
    is_m = (x / multiple).to_f == x.to_f / multiple.to_f
    is_m = false if x == 0
    return is_m
  end

  def GeneralUtilities.variance(population)
    n = 0
    mean = 0.0
    s = 0.0
    population.each { |x|
      n = n + 1
      delta = x - mean
      mean = mean + (delta / n)
      s = s + delta * (x - mean)
    }
    # if you want to calculate std deviation
    # of a sample change this to "s / (n-1)"
    return s / n
  end

  # calculate the standard deviation of a population
  # accepts: an array, the population
  # returns: the standard deviation
  def GeneralUtilities.standard_deviation(population)
    Math.sqrt(variance(population))
  end

  def GeneralUtilities.years_proportions_with_samples(years, back_samples) # an array of years, a number of background samples
    years_props = []
    years.uniq.sort_by{|x|years.grep(x)}.each{|x| years_props << [x, (back_samples * (years.grep(x).size.to_f/years.size.to_f)).round]}
    return years_props
  end

  def GeneralUtilities.years_proportions(years) # an array of years
    years_props = []
    years.uniq.sort_by{|x|years.grep(x)}.each{|x| years_props << [x, years.grep(x).size.to_f/years.size.to_f]}
    return years_props
  end

  def GeneralUtilities.eras_proportions(years) # an array of years
    # old eras
    # 0000-1969 : clim1950_pfc1950 = 1
    # 1970-1975 : clim1950_pfc1970 = 2
    # 1976-1989 : clim2000_pfc1970 = 3
    # 1990-2000 : clim2000_pfc1990 = 4
    # 2000-9999 : clim2000_pfc2000 = 5

    # new eras post worldclim
    # 0000-1969 : climate2000_pfc1950 = 1
    # 1970-1989 : climate2000_pfc1970 = 2 (combo of old 2 and 3)
    # 1990-2000 : climate2000_pfc1990 = 3
    # 2000-9999 : climate2000_pfc2000 = 4
    eras = []
    years.each {|year|
      era = EnvUtilities.get_era(year)
      eras << era
    }
    eras_props = []
    eras.uniq.sort_by{|x|eras.grep(x)}.each{|x| eras_props << [x, eras.grep(x).size.to_f/eras.size.to_f]}

    return eras_props # an array with ?
  end

  def GeneralUtilities.years_proportions2(years) # an array of years
    eras = []
    years_eras = []
    years.each {|year|
      era = EnvUtilities.get_era(year)
      eras << era
      years_eras << [year, era]
    }
    eras_props = []
    eras.uniq.sort_by{|x|eras.grep(x)}.each{|x| eras_props << [x, eras.grep(x).size.to_f/eras.size.to_f]}

    return years_eras.sort_by{|a| a[0]}, eras_props
  end

  def GeneralUtilities.get_month_name(month)
    month_name = "January" if month == 1
    month_name = "February" if month == 2
    month_name = "March" if month == 3
    month_name = "April" if month == 4
    month_name = "May" if month == 5
    month_name = "June" if month == 6
    month_name = "July" if month == 7
    month_name = "August" if month == 8
    month_name = "September" if month == 9
    month_name = "October" if month == 10
    month_name = "November" if month == 11
    month_name = "December" if month == 12

    return month_name
  end

  def GeneralUtilities.read_ascii(infile, headlines, nrows, xll, yll, cell)
    # Reads an ascii mask to an array mask in memory
    # Mask is a 2D array composed of [ [cellid1,[occ1] ],[cellid2,[occ2]],... ]
    myfile = File.open(infile)
    mask = []
    cellid = 1
    myfile.each_with_index{|line, getrow|
      #puts getrow
      if getrow > (headlines - 1)
        vals = line.split(" ")
        vals.each_with_index {|val, getcol|
          if val == "1"
            # Is this necessary to get latlong and thesn a new occurrence? Used later on?
            # Answer: Yes, lat-long used in the generation of background. We could also look it up there
            # but it has to be looked up somewhere, here or there.
            latlong = ModelUtilities.get_latlong(xll, yll, cell, getrow, getcol, nrows, headlines)
            #occ1 = NewOccurrence.new("mskspp-r" + getrow.to_s + "c" + getcol.to_s, latlong[0], latlong[1])
            occ1 = Occurrence.new(:AcceptedSpecies => "mskspp-r" + getrow.to_s + "c" + getcol.to_s, :DecimalLatitude => latlong[0], :DecimalLongitude => latlong[1]) 
            mask << [cellid,occ1]
          end
          cellid += 1
          }
      end
    }
    #puts "size: " + mask.size.to_s
    return mask
  end

  def GeneralUtilities.write_ascii(mask, ncols, nrows, xll, yll, cellsize, nodata_value, outdir)
    # Writes a mask from memory to an ESRI ascii grid
    # mask is a 2D array composed of [[cellid1,[occ1]],[cellid2,[occ2]]]
    # cellid's are assumed to be unique and in rank order, from 1 to n
    # occurrences are not used here

    # writes ascii header
    name = (outdir + "mask " + Time.now.to_s + ".asc").gsub(" ","_")
    mask_asc = File.new(name, "w")
    mask_asc.puts("ncols         " + ncols.to_s)
    mask_asc.puts("nrows         " + nrows.to_s)
    mask_asc.puts("xllcorner     " + xll.to_s)
    mask_asc.puts("yllcorner     " + yll.to_s)
    mask_asc.puts("cellsize      " + cellsize.to_s)
    mask_asc.puts("NODATA_value  " + nodata_value.to_s)

    # makes a new array with the values to be written to ascii
    cellid = 1
    asc_array = []
    mask.each {|m|
      until m[0] == cellid
        asc_array << nodata_value
        cellid += 1
      end
      asc_array << 1
      cellid += 1
      next
    }

    # Adds final nodata after last m
    (1..((nrows * ncols) - asc_array.size)).each {asc_array << nodata_value} if ((nrows * ncols) - asc_array.size) > 0

    # Writes lines to ascii file
    i = 0
    line = []
    asc_array.each {|c|
      line << c
      i += 1
      if i == ncols
        mask_asc.puts(line.join(" "))
        i = 0
        line = []
      end
    }

    mask_asc.flush
    mask_asc.close
    return name
  end

  def GeneralUtilities.write_years(years, outdir)
    name = (outdir + "years " + Time.now.to_s + ".csv").gsub(" ","_")
    years_csv = File.new(name, "w")
    years.each {|year|
      years_csv.puts year
    }
    return name
  end

  def GeneralUtilities.read_years(infile)
    years = []
    myfile = File.open(infile)
    myfile.each {|line|
      years << line.strip.to_i
    }

    return years
  end

  def GeneralUtilities.count_species(tax_hash)
    terr_spp = 0; mar_spp = 0
    i = 0
    tax_hash.each {|key|
      terr_spp += 1 if key.last[0] == "1"
      mar_spp += 1 if key.last[1] == "1"
    }
    return {"terr_spp" => terr_spp, "mar_spp" => mar_spp}
  end

end
