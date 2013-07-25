set :application, 'gofreerev-fb'
set :scm, :git
set :repository, 'https://github.com/jaros1/gofreerev-fb.git'

set :deploy_to, '/mnt/plugdisk/railsapps/capistrano/fbdemo.gofreerev.dk'

default_run_options[:pty] = true # sudo prompt = yes

# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

role :web, 'plugserver'                          # Your HTTP server, Apache/etc
role :app, 'plugserver'                          # This may be the same as your `Web` server
role :db,  'plugserver', :primary => true # This is where Rails migrations will run
# role :db,  'plugserver'

set :use_sudo, false

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end


# before/after scripts

# cap deploy               # Deploys your project.
before "deploy", :pre_deploy
after  "deploy", :post_deploy
task :pre_deploy do ; puts "### before deploy ###" ; end
task :post_deploy do ; puts "### after deploy ###" ; end

# cap deploy:check         # Test deployment dependencies.railsapps/capistrano/cache
before "deploy:check", :pre_deploy_check
after  "deploy:check", :post_deploy_check
task :pre_deploy_check do ; puts "### before deploy:check ###" ; end
task :post_deploy_check do ; puts "### after deploy:check ###" ; end

# cap deploy:cleanup       # Clean up old releases.
before "deploy:cleanup", :pre_deploy_cleanup
after  "deploy:cleanup", :post_deploy_cleanup
task :pre_deploy_cleanup do ; puts "### before deploy:cleanup ###" ; end
task :post_deploy_cleanup do ; puts "### after deploy:cleanup ###" ; end

# cap deploy:cold          # Deploys and starts a `cold' application.
before "deploy:cold", :pre_deploy_cold
after  "deploy:cold", :post_deploy_cold
task :pre_deploy_cold do ; puts "### before deploy:cold ###" ; end
task :post_deploy_cold do ; puts "### after deploy:cold ###" ; end

# cap deploy:migrate       # Run the migrate rake task.
before "deploy:migrate", :pre_deploy_migrate
after  "deploy:migrate", :post_deploy_migrate
task :pre_deploy_migrate do ; puts "### before deploy:migrate ###" ; end
task :post_deploy_migrate do ; puts "### after deploy:migrate ###" ; end

# cap deploy:migrations    # Deploy and run pending migrations.
before "deploy:migrations", :pre_deploy_migrations
after  "deploy:migrations", :post_deploy_migrations
task :pre_deploy_migrations do ; puts "### before deploy:migrations ###" ; end
task :post_deploy_migrations do ; puts "### after deploy:mirailsapps/capistrano/cachegrations ###" ; end

# cap deploy:pending       # Displays the commits since your last deploy.
before "deploy:pending", :pre_deploy_pending
after  "deploy:pending", :post_deploy_pending
task :pre_deploy_pending do ; puts "### before deploy:pending ###" ; end
task :post_deploy_pending do ; puts "### after deploy:pending ###" ; end

# cap deploy:pending:diff  # Displays the `diff' since your last deploy.
before "deploy:diff", :pre_deploy_diff
after  "deploy:diff", :post_deploy_diff
task :pre_deploy_diff do ; puts "### before deploy:diff ###" ; end
task :post_deploy_diff do ; puts "### after deploy:diff ###" ; end

# cap deploy:rollback      # Rolls back to a previous version and restarts.
before "deploy:rollback", :pre_deploy_rollback
after  "deploy:rollback", :post_deploy_rollback
task :pre_deploy_rollback do ; puts "### before deploy:rollback ###" ; end
task :post_deploy_rollback do ; puts "### after deploy:rollback ###" ; end

# cap deploy:rollback:code # Rolls back to the previously deployed version.
before "deploy:rollback_code", :pre_deploy_rollback_code
after  "deploy:rollback_code", :post_deploy_rollback_code
task :pre_deploy_rollback_code do ; puts "### before deploy:rollback_code ###" ; end
task :post_deploy_rollback_code do ; puts "### after deploy:rollback_code ###" ; end

# cap deploy:setup         # Prepares one or more servers for deployment.
before "deploy:setup", :pre_deploy_setup
after  "deploy:setup", :post_deploy_setup
task :pre_deploy_setup do ; puts "### before deploy:setup ###" ; end
task :post_deploy_setup do ; puts "### after deploy:setup ###" ; end

# cap deploy:symlink       # Updates the symlink to the most recently deployed ...
before "deploy:symlink", :pre_deploy_symlink
after  "deploy:symlink", :post_deploy_symlink
task :pre_deploy_symlink do ; puts "### before deploy:symlink ###" ; end
task :post_deploy_symlink do ; puts "### after deploy:symlink ###" ; end

# cap deploy:update        # Copies your project and updates the symlink.
before "deploy:update", :pre_deploy_update
after  "deploy:update", :post_deploy_update
task :pre_deploy_update do
  puts "### before deploy:update ###"
  # to-do: no capistrano_deploy_update_pre.rb script in first deploy ...
  # run "ruby #{File.join(current_path,'script','capistrano_deploy_update_pre.rb')}"
end
task :post_deploy_update do
  puts "### after deploy:update ###"
  run "ruby #{File.join(current_path,'script','capistrano_deploy_update_post.rb')}"
end

# cap deploy:update_code   # Copies your project to the remote servers.
# cap deploy:update_code   # Copies your project to the remote servers.
before "deploy:update_code", :pre_deploy_update_code
after  "deploy:update_code", :post_deploy_update_code
task :pre_deploy_update_code do ; puts "### before deploy:update_code ###" ; end
task :post_deploy_update_code do ; puts "### after deploy:update_code ###" ; end

# cap deploy:upload        # Copy files to the currently deployed version.
before "deploy:upload", :pre_deploy_upload
after  "deploy:upload", :post_deploy_upload
task :pre_deploy_upload do ; puts "### before deploy:upload ###" ; end
task :post_deploy_upload do ; puts "### after deploy:upload ###" ; end

# cap deploy:web:disable   # Present a maintenance page to visitors.
before "deploy:disable", :pre_deploy_disable
after  "deploy:disable", :post_deploy_disable
task :pre_deploy_disable do ; puts "### before deploy:disable ###" ; end
task :post_deploy_disable do ; puts "### after deploy:disable ###" ; end

# cap deploy:web:enable    # Makes the application web-accessible again.
before "deploy:enable", :pre_deploy_enable
after  "deploy:enable", :post_deploy_enable
task :pre_deploy_enable do ; puts "### before deploy:enable ###" ; end
task :post_deploy_enable do ; puts "### after deploy:enable ###" ; end

# cap invoke               # Invoke a single command on the remote servers.
before "deploy:invoke", :pre_deploy_invoke
after  "deploy:invoke", :post_deploy_invoke
task :pre_deploy_invoke do ; puts "### before deploy:invoke ###" ; end
task :post_deploy_invoke do ; puts "### after deploy:invoke ###" ; end

# cap shell                # Begin an interactive Capistrano session.
before "deploy:shell", :pre_deploy_shell
after  "deploy:shell", :post_deploy_shell
task :pre_deploy_shell do ; puts "### before deploy:shell ###" ; end
task :post_deploy_shell do ; puts "### after deploy:shell ###" ; end