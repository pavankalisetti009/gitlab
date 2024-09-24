# frozen_string_literal: true

scope module: :gitlab_subscriptions do
  namespace :trials do
    resource :duo_pro, only: [:new, :create]
    resource :duo_enterprise, only: [:new, :create]
  end

  resources :trials, only: [:new, :create]
end
