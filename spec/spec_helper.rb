require 'bundler/setup'
require 'clean_rm'

$script_name = 'trash'

def trash(*args)
  system('bundle', 'exec', 'bin/trash', *args)
end

def output_nothing()
  output('').to_stdout_from_any_process
end

def output_string(string)
  output(string + "\n").to_stdout_from_any_process
end

def output_contents_of(file)
  output(File.read('spec/data/' + file)).to_stdout_from_any_process
end

def output_matching(pattern)
  output(pattern).to_stdout_from_any_process
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
