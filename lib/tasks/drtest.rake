require 'open3'
require 'beanstalk-client'
require 'drmap'
require 'pp'

class BS
  def start
    puts "Starting beanstalkd..."
    fork do
      Open3::popen3("beanstalkd")
    end
    sleep 5
  end

  def stop
    fork do
      Open3::popen3("killall -9 beanstalkd")
    end
    puts "Killed beanstalkd..."
  end

end

namespace :dr do
  Drmap::BeanstalkPool.hosts = ['localhost:11300']

  def find_unit_tests
    test_list = []
    files = Dir.glob("#{Rails.root}/test/unit/*.rb")
    files.each do |file|
      tests = File.open(file) {|f| f.read.scan(/def test_.*$/)}.collect{|x| x.split[1]}
      tests.each do |test|
        test_list << "#{file}|#{test}"
      end
    end
    test_list
  end

  desc "Distribute tasks"
  task :test do
    # drtest = BS.new
    # drtest.start
    test_list = find_unit_tests
    results = test_list.drmap do |file_method|
      file, method = file_method.split("|")
      # machine = ENV["MACHINE"]
      cmd = "ruby -Ilib:test #{file} --name #{method}"
      # puts "Cmd: #{cmd}"
      stdin, stdout, stderr = Open3::popen3(cmd)
      stdout_str = stdout.readlines
      stderr_str = stderr.readlines
      [stdout_str, stderr_str]
    end
    pp results
    # drtest.stop
  end

  desc "Run tests"
  task :runner do
    pool = Drmap::BeanstalkPool.new
    worker = Drmap::BeanstalkWorker.new(pool)
    puts "Waiting..."
    worker.process
  end

end
