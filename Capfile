load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load 'config/deploy'

after "deploy:update_code", "db:symlink" 
after "deploy:update_code", "deploy:fix_runner"
after "deploy:setup", "deploy:fuseforge_setup"

namespace :db do
  desc "Make symlink for database yaml" 
  task :symlink do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml" 
  end
end

# http://nubyonrails.com/articles/tips-for-upgrading-to-capistrano-2
set :mongrel_config, "/etc/mongrel_cluster/#{application}.yml" 

namespace :deploy do

  task :fix_runner do
  end

  task :fuseforge_setup do
  	run "mkdir -p #{shared_path}/config"
    run "mkdir -p #{shared_path}/projects"
  end

end