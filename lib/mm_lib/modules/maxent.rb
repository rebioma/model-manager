module Maxent
  def Maxent.run_maxent(path, mem, output, args_array, exts_hash)
    cmd_start = ["java", mem, "-cp", path, exts_hash[:density]].join(" ")
    if exts_hash[:density] = "density.MaxEnt"
      output = "outputdirectory=" + output
      exts_hash[:lambdas] = "samplesfile=" + exts_hash[:samples] # sample.swd 
      exts_hash[:background] = "environmentallayers=" + exts_hash[:background] # background.swd or directory of env grids
    end
    cmd = [cmd_start,exts_hash[:lambdas],exts_hash[:background],output,args_array.join(" ")].join(" ")
    success = system(cmd)
    return success
  end

end