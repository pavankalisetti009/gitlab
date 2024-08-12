# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_repository, class: '::Search::Zoekt::Repository' do
    project { association(:project) }
    zoekt_index { association(:zoekt_index) }
    project_identifier { project.id }
  end
end
