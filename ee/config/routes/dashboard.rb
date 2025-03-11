# frozen_string_literal: true

resource :dashboard, controller: 'dashboard', only: [] do
  scope module: :dashboard do
    resources :projects, only: [:index] do
      collection do
        ## TODO: Migrate this route to 'projects#index'
        ## Tracked in https://gitlab.com/gitlab-org/gitlab/-/issues/523698
        get :removed
      end
    end
  end
end
