# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'config/initializers/covered_experiences.rb', feature_category: :scalability do
  it 'retrieves each valid covered experience in the registry' do
    path = Pathname.new(Labkit::CoveredExperience.configuration.registry_path)
    experiences = path.glob('*.yml')

    experiences.each do |filepath|
      xp_name = filepath.basename('.yml').to_s

      expect { Labkit::CoveredExperience.get(xp_name) }.not_to raise_error
    end
  end

  it 'fails when covered experience does not exist' do
    expect do
      Labkit::CoveredExperience.get('non_existent_experience')
    end.to raise_error(Labkit::CoveredExperience::NotFoundError)
  end

  it 'fails when covered experience in the registry is invalid' do
    Tempfile.create(['invalid_experience', '.yml'], Labkit::CoveredExperience.configuration.registry_path) do |f|
      f.write('invalid_key: invalid_value')
      f.close
      xp_name = File.basename(f.path, '.*')

      expect { Labkit::CoveredExperience.get(xp_name) }.to raise_error(Labkit::CoveredExperience::NotFoundError)
    end
  end
end
