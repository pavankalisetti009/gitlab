# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_repository, class: '::Search::Zoekt::Repository' do
    project { association(:project) }
    zoekt_index { association(:zoekt_index) }
    project_identifier { project.id }
    state { Search::Zoekt::Repository.states.fetch(:pending) }
    size_bytes { 10.megabytes }
  end
end
