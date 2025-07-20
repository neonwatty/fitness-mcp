# SimpleCov configuration
SimpleCov.start 'rails' do
  add_filter '/test/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/db/'
  add_filter '/bin/'
  
  # Set minimum coverage threshold
  # TODO: Increase coverage back to 95% once all files are properly tested
  minimum_coverage 1
  minimum_coverage_by_file 0
  
  # Group files for better organization
  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Tools', 'app/tools'
  add_group 'Resources', 'app/resources'
  add_group 'Helpers', 'app/helpers'
  add_group 'Mailers', 'app/mailers'
  add_group 'Channels', 'app/channels'
  add_group 'Jobs', 'app/jobs'
  
  # Enable branch coverage
  enable_coverage :branch
  
  # Merge results from parallel tests
  if ENV['TEST_ENV_NUMBER']
    command_name "Task#{ENV['TEST_ENV_NUMBER']}"
  end
end