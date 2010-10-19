require 'rubygems'
require 'active_record'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'yaml'
require 'mysql'
require 'logger'

begin
  config = YAML.load(File.open("#{File.dirname(__FILE__)}/../db.yml"))
rescue
  $stderr.puts "You must create a file db.yml in the root directory with database configuration"
  exit
end

namespace :db do
  desc "Set up the database environment"
  task :environment do
    ActiveRecord::Base.establish_connection(config)
    ActiveRecord::Base.connection
  end

  desc "Create database"
  task :create do
    #From Rake's databases.rake
    @charset   = ENV['CHARSET']   || 'utf8'
    @collation = ENV['COLLATION'] || 'utf8_unicode_ci'
    creation_options = {:charset => (config['charset'] || @charset), :collation => (config['collation'] || @collation)}
    error_class = config['adapter'] =~ /mysql2/ ? Mysql2::Error : Mysql::Error
    access_denied_error = 1045
    begin
      ActiveRecord::Base.establish_connection(config.merge('database' => nil))
      ActiveRecord::Base.connection.create_database(config['database'], creation_options)
      ActiveRecord::Base.establish_connection(config)
    rescue error_class => sqlerr
      if sqlerr.errno == access_denied_error
        print "#{sqlerr.error}. \nPlease provide the root password for your mysql installation\n>"
        root_password = $stdin.gets.strip
        grant_statement = "GRANT ALL PRIVILEGES ON #{config['database']}.* " \
          "TO '#{config['username']}'@'localhost' " \
          "IDENTIFIED BY '#{config['password']}' WITH GRANT OPTION;"
        ActiveRecord::Base.establish_connection(config.merge(
            'database' => nil, 'username' => 'root', 'password' => root_password))
        ActiveRecord::Base.connection.create_database(config['database'], creation_options)
        ActiveRecord::Base.connection.execute grant_statement
        ActiveRecord::Base.establish_connection(config)
      else
        $stderr.puts sqlerr.error
        $stderr.puts "Couldn't create database for #{config.inspect}, charset: #{config['charset'] || @charset}, collation: #{config['collation'] || @collation}"
        $stderr.puts "(if you set the charset manually, make sure you have a matching collation)" if config['charset']
      end
    end
  end
  
  desc "Drop the database"
  task :drop do
    begin
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection.drop_database config['database']
    rescue Exception => e
      $stderr.puts "Couldn't drop #{config['database']} : #{e.inspect}"
    end
  end
  
  desc "Migrate the database"
  task :migrate => :environment do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate("db/migrate/")
  end
  
  desc "Drop, recreate and migrate the database"
  task :reset => [:drop, :create, :migrate]
  
  desc "Go up a migration"
  task :up => :environment do
    version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
    raise "VERSION is required" unless version
    ActiveRecord::Migrator.run(:up, "db/migrate/", version)
    Rake::Task["db:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
  end
  
  desc "Go down a migration"
  task :down => :environment do
    version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
    raise "VERSION is required" unless version
    ActiveRecord::Migrator.run(:down, "db/migrate/", version)
    Rake::Task["db:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
  end
  
  desc 'Rolls the schema back to the previous version (specify steps w/ STEP=n).'
  task :rollback => :environment do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    ActiveRecord::Migrator.rollback('db/migrate/', step)
    Rake::Task["db:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
  end
  
  #From github.com/bmizerany/sinatra-activerecord
  desc "create an ActiveRecord migration in ./db/migrate"
  task :create_migration do
    name = ENV['NAME']
    abort("no NAME specified. use `rake db:create_migration NAME=create_users`") if !name

    migrations_dir = File.join("db", "migrate")
    version = ENV["VERSION"] || Time.now.utc.strftime("%Y%m%d%H%M%S") 
    filename = "#{version}_#{name}.rb"
    migration_name = name.gsub(/_(.)/) { $1.upcase }.gsub(/^(.)/) { $1.upcase }

    FileUtils.mkdir_p(migrations_dir)

    open(File.join(migrations_dir, filename), 'w') do |f|
      f << (<<-EOS).gsub("      ", "")
      class #{migration_name} < ActiveRecord::Migration
        def self.up
        end

        def self.down
        end
      end
      EOS
    end
  end
end
