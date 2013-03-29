# Module with utilities related to environmental layers
module EnvUtilities
  def EnvUtilities.load_layer(layer)
    layerfile = File.open(layer)
    lines = layerfile.readlines
    b = []
    lines.each_with_index{|c, i| c.chomp.split(" ").each{|w| b << w} unless i < 6}
    return b
  end

  def EnvUtilities.get_era(year)
    era = 1 if year < 1970
    era = 2 if (year >= 1970 and year < 1990)
    era = 3 if (year >= 1990 and year < 2000)
    era = 4 if year >= 2000
    return era
  end

  def EnvUtilities.get_year(era)
    year = "<1970" if era == 1
    year = "1970-1990" if era == 2
    year = "1990-2000" if era == 3
    year = ">2000" if era == 4
    return year
  end

  def EnvUtilities.eras_proportions(years) # an array of years
    # new eras post worldclim/ipcc 4
    # 0000-1969 : climate2000 & pfc1950 = 1
    # 1970-1989 : climate2000 & pfc1970 = 2 (combo of old 2 and 3)
    # 1990-2000 : climate2000 & pfc1990 = 3
    # 2000-9999 : climate2000 & pfc2000 = 4
    eras = []
    years.each {|year|
      era = EnvUtilities.get_era(year)
      eras << era
    }
    eras_props = []
    eras.uniq.sort_by{|x|eras.grep(x)}.each{|x| eras_props << [x, eras.grep(x).size.to_f/eras.size.to_f]}
    return eras_props # an array with ?
  end

  def EnvUtilities.get_forest_era(year, props)
    #eras2 = eras.split(",")
    eras2 = props["forest_eras"].split(",")
    #len = eras2.size
    era = 0
    eras2.each_with_index do |e, a|
      #puts "in year: " + year.to_s
      #puts "current e: " + e.to_s
      #puts "current era: " + era.to_s
      #puts "------"
      if year < e.to_i
        a == 0 ? z = a : z = a - 1 # catch first loop if year < 1950
        era = eras2[z].to_i
        break
      else
        era = e.to_i
      end
    end
    #puts "final era: " + era.to_s
    #return "pfc" + era.to_s + ".asc" # constructs the name of the layer from year
    return props["for_era_layers"][era]
  end

  def EnvUtilities.get_forest_ascii(era, props)
    #ascii = "pfc1950.asc" if era == 1
    #ascii = "pfc1970.asc" if era == 2 || era == 3
    #ascii = "pfc1990.asc" if era == 4
    #ascii = "pfc2000.asc" if era == 5
    ascii = props["for_era_layers"][1950] if era == 1
    ascii = props["for_era_layers"][1970] if era == 2
    ascii = props["for_era_layers"][1990] if era == 3
    ascii = props["for_era_layers"][2000] if era == 4
    return ascii
  end

  def EnvUtilities.get_value(layerfile, props, getrow, getcol) #offset built into getrow
    # Requires bash to run, uses tail and head to get the line of interest from large file
    begin
      tailcmd = "tail -n +" + (getrow + 1).to_s + " " + props['env_path'] + layerfile + " > " + props['tmp'] + "tail.asc"
      headcmd = "head -n 1 " + props['tmp'] + "tail.asc" + " > " + props['tmp'] + "head.asc"
      success = system(tailcmd) # use tail to get file from line n onwards saves to temp file on disc boo
      successagain = system(headcmd) # use head to get first line of boo saved to boohoo
      afile = File.open(props['tmp'] + "head.asc","r")
      aline = afile.readlines
      aval = aline[0].chomp.split(" ")[getcol]
      afile.close
      File.delete(props['tmp'] + "head.asc")
      File.delete(props['tmp'] + "tail.asc")
      aval2 = sprintf( "%0.07f", aval)
      return aval2 # note: string with 7 decimal places
    rescue
      puts "rescue (getrow): " + getrow.to_s + ", (getcol): " + getcol.to_s + ", (layer): " + layerfile 
    end
  end

  def EnvUtilities.fix_asc(ascii, offset)
    a = File.open(ascii, "r")
    newname = ascii + "2"
    out = File.new(newname, "w")
    b = a.readlines
    b.each_with_index {|line, i|
      if i < offset
        fixline = line
        out.puts(fixline)
      else
        c = line.split(" ")
        fixline = []
        c.each do |r|
          if r != "-9999"
            r = r.to_f.to_s # converts exponential numbers less than e-05
            r = EnvUtilities.exponential_to_float(r) if r[r.size - 4] == 101  # byte for "e"
          end
          fixline << r
        end
        out.puts(fixline.join(" "))
      end
      }
    a.close
    out.flush
    out.close
    return newname
  end

  # Only works on negative exponential notation!
  # Also, assumes two digit notation e-06; not e-3!!
  # Will fail if passed exponential numbers with less than e05, e.g. 1.234e-04
  def EnvUtilities.exponential_to_float(r)
    #r = r.to_s
    #if r[r.size - 3] == 45 # minus sign such as 9.12342e-05
    str = ["0."]
    n = ([r[r.size - 1]].pack('c*').to_i) + 10 * ([r[r.size - 2]].pack('c*').to_i)
    #puts ([r[r.size - 1]].pack('c*').to_i)
    #puts ([r[r.size - 2]].pack('c*').to_i)
    #puts n
    (1..n - 1).each do str << "0" end
    (0..r.size - 1).each {|t|
        q = [r[t]].pack('c*')
        next if q == "."
        break if q == "e"
        str << q.to_s
       }
    #end
    r = str.join("")
    return r
  end
end
