# frozen_string_literal: true

resources :virtual_registries, only: [:index]
namespace :virtual_registries do
  namespace :maven do
    resources :registries_and_upstreams, path: '', only: [:index]
    resources :registries, only: [:new, :create, :show, :edit, :update, :destroy]
    resources :upstreams, only: [:show, :edit]
  end
end
