# frozen_string_literal: true

namespace :subscriptions do
  resources :groups, only: [:new, :edit, :update, :create]
end
