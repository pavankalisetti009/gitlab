# frozen_string_literal: true

namespace :subscriptions do
  resources :groups, only: [:new, :edit, :update, :create]
  resources :hand_raise_leads, only: :create, controller: '/gitlab_subscriptions/hand_raise_leads'
end
