# To change this template, choose Tools | Templates
# and open the template in the editor.

module DbUtilities
  def DbUtilities.run_mysql_bash(config, db)
    bash_file = File.new(config['trainingdir'] + "mysql_script.sh","w")
    bash_source_file = File.open("mysql_script.template.sh","r")
    bash_source_lines = bash_source_file.readlines

    # Replace with local variables
    bash_source_lines.each_with_index {|line, i|
      line = line.sub("zzz", db['database']['user']) if i == 2
      line = line.sub("zzz", db['database']['password']) if i == 3
      line = line.sub("zzz", db['database']['database_in']) if i == 4
      line = line.sub("zzz", config['trainingdir'] + db['database']['database_in'] + ".dump") if i == 5
      line = line.sub("zzz", db['database']['database']) if i == 6
      bash_file.puts(line)
    }
    bash_file.flush
    bash_file.close
    # USING SUDO FOR NOW UNTIL MYSQL CLIENT REPAIRED
    # THIS WILL NOT WORK THROUGH NETBEANS
    # RUN MAIN $ ruby main.rb
    runbash = system("sudo bash " + config['trainingdir'] + File::SEPARATOR + "mysql_script.sh")
    return runbash
  end

  def DbUtilities.run_ascii_table_bash(config, db)
    bash_file = File.new(config['trainingdir'] + "mysql_script2.sh","w")
    bash_source_file = File.open("mysql_script2.template.sh","r")
    bash_source_lines = bash_source_file.readlines
    # Replace with local variables
    bash_source_lines.each_with_index {|line, i|
      line = line.sub("zzz", db['database']['user']) if i == 2 ## DBUSER
      line = line.sub("zzz", db['database']['password']) if i == 3 ## DBPASSWORD
      line = line.sub("zzz", db['database']['database'] + "." + db['database']['copy_table']) if i == 4 ## DBTABLENAME
      line = line.sub("zzz", db['database']['database_in'] + "." + db['database']['final_table']) if i == 5 ## DBFINALTABLE
      bash_file.puts(line)
    }
    bash_file.flush
    bash_file.close
    # USING SUDO FOR NOW UNTIL MYSQL CLIENT REPAIRED
    # THIS WILL NOT WORK THROUGH NETBEANS
    # RUN MAIN $ ruby main.rb
    runbash = system("sudo bash " + config['trainingdir'] + File::SEPARATOR + "mysql_script2.sh")
    return runbash
  end
    
end
