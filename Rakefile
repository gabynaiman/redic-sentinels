require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:spec) do |t|
  t.libs << 'spec'
  t.pattern = 'spec/**/*_spec.rb'
  t.verbose = false
  t.warning = false
  t.loader = nil if ENV['TEST']
  ENV['TEST'], ENV['LINE'] = ENV['TEST'].split(':') if ENV['TEST'] && !ENV['LINE']
  t.options = ''
  t.options << "--name=/#{ENV['NAME']}/ " if ENV['NAME']
  t.options << "-l #{ENV['LINE']} " if ENV['LINE'] && ENV['TEST']
end

task :console do
  require 'pry'
  require 'redic-sentinels'
  ARGV.clear
  Pry.start
end

task default: :spec

namespace :redis do

  REDIS_CONFIGURATIONS = Dir['config/*.conf'].map { |f| File.basename(f,'.conf')[6..-1] }

  def start_redis(config)
    args = config.start_with?('sentinel') ? '--sentinel' : ''
    sh "sudo redis-server config/redis-#{config}.conf #{args}"
  rescue => ex
    puts "Cant start #{config}: #{ex.message}"
  end

  def stop_redis(config)
    pidfile = File.expand_path "/tmp/redic-sentinels-#{config}.pid"
    pid = File.read pidfile
    sh "sudo kill -s TERM #{pid}"
  rescue => ex
    puts "Cant stop #{config}: #{ex.message}"
  end

  desc 'Start Redis Server for specific configuration (CONFIG=master)'
  task :start do
    start_redis ENV.fetch('CONFIG').downcase
  end

  namespace :start do
    desc 'Start Redis Server for all configurations'
    task :all do
      REDIS_CONFIGURATIONS.each { |c| start_redis c }
    end
  end

  desc 'Stop Redis Server for specific configuration (CONFIG=master)'
  task :stop do
    stop_redis ENV.fetch('CONFIG').downcase
  end

  namespace :stop do
    desc 'Stop Redis Server for all configurations'
    task :all do
      REDIS_CONFIGURATIONS.each { |c| stop_redis c }
    end
  end

end