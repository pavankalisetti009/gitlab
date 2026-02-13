# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'EE-specific user routing' do
  describe 'devise_for users scope' do
    it 'defines regular and Geo routes' do
      [
        ['/users/sign_in', 'GET', 'new'],
        ['/users/auth/geo/sign_in', 'GET', 'new'],
        ['/users/sign_in', 'POST', 'create'],
        ['/users/auth/geo/sign_in', 'POST', 'create'],
        ['/users/sign_out', 'POST', 'destroy'],
        ['/users/auth/geo/sign_out', 'POST', 'destroy']
      ].each do |path, method, action|
        expect(Rails.application.routes.recognize_path(path, { method: method })).to include(
          { controller: 'sessions', action: action }
        )
      end
    end

    shared_examples 'routes session paths' do |route_type|
      before do
        allow(Gitlab::Geo).to receive(:secondary?).with(infer_without_database: true).and_return(route_type == :geo)
        Rails.application.reload_routes!
      end

      after do
        allow(Gitlab::Geo).to receive(:secondary?).with(infer_without_database: true).and_call_original
        Rails.application.reload_routes!
      end

      it "handles #{route_type} named route helpers" do
        sign_in_path, sign_out_path = case route_type
                                      when :regular then
                                        ['/users/sign_in', '/users/sign_out']
                                      when :geo then
                                        ['/users/auth/geo/sign_in', '/users/auth/geo/sign_out']
                                      end

        expect(Gitlab::Routing.url_helpers.new_user_session_path).to eq(sign_in_path)
        expect(Gitlab::Routing.url_helpers.destroy_user_session_path).to eq(sign_out_path)
      end
    end

    context 'when a Geo secondary, checked without a database connection' do
      it_behaves_like 'routes session paths', :regular
    end

    context 'Geo database is configured' do
      it_behaves_like 'routes session paths', :geo
    end
  end

  describe 'sign up routes', feature_category: :acquisition do
    let(:trial_user_match?) { false }

    before do
      allow_any_instance_of(Onboarding::TrialUserConstraint).to receive(:matches?).and_return(trial_user_match?) # rubocop:disable RSpec/AnyInstanceOf -- Needed as it is not the next instance
    end

    it 'routes to welcome controller' do
      expect(get: '/users/sign_up/welcome').to route_to(controller: 'registrations/welcome', action: 'show')
      expect(patch: '/users/sign_up/welcome').to route_to(controller: 'registrations/welcome', action: 'update')
    end

    it 'routes to trial_welcome controller for new and create' do
      expect(get: '/users/sign_up/trial_welcome/new')
        .to route_to(controller: 'registrations/trial_welcome', action: 'new')
      expect(post: '/users/sign_up/trial_welcome')
        .to route_to(controller: 'registrations/trial_welcome', action: 'create')
    end

    context 'when trial user constraint is satisfied' do
      let(:trial_user_match?) { true }

      it 'routes to trial_welcome controller for show and update' do
        expect(get: '/users/sign_up/welcome').to route_to(controller: 'registrations/trial_welcome', action: 'show')
        expect(patch: '/users/sign_up/welcome').to route_to(controller: 'registrations/trial_welcome', action: 'update')
      end
    end
  end
end
