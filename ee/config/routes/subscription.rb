# frozen_string_literal: true

namespace :subscriptions do
  resources :groups, only: [:new, :edit, :update, :create]
  resources :hand_raise_leads, only: :create
end
