desc "runs Maxent models"
namespace :model_manager do
  task :main => :environment do
  	rails = Rails.root.join("config", "environment.rb")
    ruby "lib/mm_lib/main.rb #{rails}"
  end
end

desc "test"
namespace :users do
  task :list => :environment do
    puts Occurrence.first
  end
end
