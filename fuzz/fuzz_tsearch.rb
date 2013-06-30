require "bundler/setup"
require "pg_search"
require 'fuzzbert'
require "securerandom"

begin
  require "pg"
  error_class = PGError
rescue
  begin
    require "arjdbc/jdbc/core_ext"
    error_class = ActiveRecord::JDBCError
  rescue LoadError, StandardError
    raise "I don't know what database adapter you're using, sorry."
  end
end

begin
  database_user = if ENV["TRAVIS"]
                    "postgres"
                  else
                    ENV["USER"]
                  end

  ActiveRecord::Base.establish_connection(:adapter  => 'postgresql',
                                          :database => 'pg_search_test',
                                          :username => database_user,
                                          :min_messages => 'warning')
  connection = ActiveRecord::Base.connection
  postgresql_version = connection.send(:postgresql_version)
  connection.execute("SELECT 1")
rescue error_class => e
  at_exit do
    puts "-" * 80
    puts "Unable to connect to database.  Please run:"
    puts
    puts "    createdb pg_search_test"
    puts "-" * 80
  end
  raise e
end

connection = ActiveRecord::Base.connection
connection.drop_table("fuzz_models") if connection.table_exists?("fuzz_models")
connection.create_table("fuzz_models") do |t|
  t.string :text
end

class FuzzModel < ActiveRecord::Base
  include PgSearch
  pg_search_scope :search, :against => :text
end

fuzz "tsearch search phrases" do
  deploy do |data|
    begin
      FuzzModel.search(data)
    rescue
      puts $!
      # require "pry"
      # binding.pry
    end
  end

  data "completely random" do
    Proc.new do
      s = ""
      1024.times do
        s << SecureRandom.hex(2).to_i(16) rescue nil
      end
      s
    end
  end
end
