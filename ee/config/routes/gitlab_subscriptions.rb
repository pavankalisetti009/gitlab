# frozen_string_literal: true

scope module: :gitlab_subscriptions do
  namespace :trials do
    resource :duo_pro, only: [:new, :create]
    resource :duo_enterprise, only: [:new, :create]
  end

  constraints(GitlabSubscriptions::TrialTypeConstraint.new) do
    # saas => GitlabSubscriptions::TrialsController
    resources :trials, only: [:new, :create]
  end
  # self managed => GitlabSubscriptions::SelfManaged::TrialsController
  resource :trials, only: [:new, :create], controller: 'self_managed/trials', as: :self_managed_trials

  resources :groups, only: [:new, :create], path: 'subscriptions/groups', as: :gitlab_subscriptions_groups
  resource :subscriptions, only: [:new] do
    get :buy_minutes
    get :buy_storage
    get :payment_form
    post :validate_payment_method
  end
  resources :hand_raise_leads, only: :create, path: 'gitlab_subscriptions/hand_raise_leads',
    as: 'gitlab_subscriptions_hand_raise_leads' do
    collection do
      post :track_cart_abandonment
    end
  end
end
