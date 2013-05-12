# copy output to tomcat with options
# not working currently - permissions issues on tomcat folders, cannot write, cannot delete, cannot chown
# except as sudo, and cannot sudo rake
# one solution might be to run (this and all rake tasks?) as tomcat user, but at moment cannot open ssh session as tomcat
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
# COPY:
# Gets properties from properties file, do the actual copying depending on options in properties.yml
#
##
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
      if props['links'] # copy links only
        FileUtils.ln_s(f, props['models_path'] + f.sub(props['outputdir'], ""), :force => true)
      else # copy full files
        FileUtils.cp_r props['outputdir'] + '/.', props['models_path']
      end
    end
  }

  # Change ownership (not relevant for links, but ok)
  Dir.glob(props['models_path'] + '**/*').each {|e| File.chown props['owner_uid2'], props['owner_uid2'], e} if props['chown']
  msg = "Changing model ownership..."; puts msg if props['chown']; log.info msg if props['chown']
else
  msg = "Move_to_tomcat was set to false in properties.yml. No files moved or copied. Exiting..."; puts msg; log.info msg
end