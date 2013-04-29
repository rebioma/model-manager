desc "runs Maxent models"
namespace :model_manager do
  task :main => :environment do
  	rails = Rails.root.join("config", "environment.rb")
    ruby "lib/mm_lib/main.rb #{rails}"
  end
end

desc "copies results to Tomcat:"
namespace :model_manager do
  task :copy => :environment do
  	rails = Rails.root.join("config", "environment.rb")
    ruby "lib/mm_lib/copy_output.rb #{rails}"
  end
end
