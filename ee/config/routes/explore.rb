# frozen_string_literal: true

namespace :explore do
  get '/ai-catalog/(*vueroute)' => 'ai_catalog#index', as: :ai_catalog, format: false
end
