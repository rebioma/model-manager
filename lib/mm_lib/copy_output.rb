# 1. chown output dir if prop
# 2. delete tomcat if prop
# 3. mount to tomcat if prop
# run each as system(cmd), cmd includes sudo - will prompt for pw
require ARGV[0] #rails_environment
require 'logger'
require 'fileutils'
# modules
require_relative 'modules/general_utilities'

#
# SETUP:
# Gets properties from properties file, start logging
#
##
fn = File.dirname(File.expand_path(__FILE__)) + '/yml/properties.yml'
props = YAML::load(File.open(fn))
log = Logger.new(props['logs'] + "_COPY_OUTPUT_LOG_" + Time.now.to_s.gsub(" ","_") + ".txt")

#
# CHOWN:
# Chowns files in output to user defined in properties
# REQUIRES SUDO and will prompt for pw
##
if props['chown']
  msg = "Changing model ownership..."; puts msg; log.info msg
  cmd = "sudo chown -R #{props['owner_uid']}:#{props['group_uid']} #{props['outputdir']}*"
  result = system(cmd) 
  msg = "Chown result: #{result}"; puts msg; log.info msg
end

#
# DELETE:
# Deletes existing files in tomcat models folder
# REQUIRES SUDO and will prompt for pw
##
if props['delete_old_tomcat']
  msg = "Deleting existing models from tomcat directory: " + props['models_path']; puts msg; log.info msg
  cmd1 = "sudo rm -r #{props['models_path']}"
  cmd2 = "sudo mkdir #{props['models_path']}"
  result1 = system(cmd1)
  msg = "Delete old tomcat result: #{result1}"; puts msg; log.info msg
  result2 = system(cmd2)
  msg = "Make new models directory on tomcat result: #{result2}"; puts msg; log.info msg
end

#
# MOUNT:
# Uses mount to "copy" output files to tomcat
# REQUIRES SUDO and will prompt for pw
##
if props['mount_to_tomcat']
  msg = "Deleting existing models from tomcat directory: " + props['models_path']; puts msg; log.info msg
  cmd = "sudo mount --bind #{props['outputdir']} #{props['models_path']}"
  result = system(cmd)
  msg = "Mount models to tomcat result: #{result}"; puts msg; log.info msg
end




