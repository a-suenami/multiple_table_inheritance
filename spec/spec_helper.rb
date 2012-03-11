require 'active_record'
require 'database_cleaner'
require 'multiple_table_inheritance'

MultipleTableInheritance::Railtie.insert

require 'support/tables'
require 'support/models'

module MultipleTableInheritanceSpecHelper
  def mock_everything!
    3.times do |i|
      team = Team.create!(:name => "Team#{i}")
      language = Language.create!(:name => "Java 1.#{i + 4}")
    end
    
    3.times do |i|
      Programmer.create!(
          :first_name => "Joe",
          :last_name => "Schmoe #{i}",
          :salary => 60000 + (i * 5000),
          :team => Team.first,
          :languages => Language.limit(2))  # programmer-specific relationship
      
      Manager.create!(
          :first_name => "Bob",
          :last_name => "Smith #{i}",
          :salary => 70000 + (i * 2500),
          :team => Team.first,
          :bonus => i * 2500)  # manager-specific field
    end
  end
end

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  include MultipleTableInheritanceSpecHelper
  
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.before(:each) do
    DatabaseCleaner.start
  end
  
  config.after(:each) do
    DatabaseCleaner.clean
  end
end
