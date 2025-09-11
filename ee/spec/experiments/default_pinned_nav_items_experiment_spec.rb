# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DefaultPinnedNavItemsExperiment, :experiment, feature_category: :activation do
  let_it_be(:user, reload: true) { create(:user) }

  let(:exp) { experiment(:default_pinned_nav_items) }

  context 'with candidate experience' do
    before do
      stub_experiments(default_pinned_nav_items: :candidate)
    end

    it 'does not raise' do
      expect(exp).to register_behavior(:candidate).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end

  context 'with control experience' do
    before do
      stub_experiments(default_pinned_nav_items: :control)
    end

    it 'does not raise an error' do
      expect(exp).to register_behavior(:control).with(nil)
      expect { exp.run }.not_to raise_error
    end
  end

  context "for non new trial registrations" do
    it "includes trial registrations" do
      user.update!(onboarding_status_registration_type: 'trial')
      expect(exp).not_to exclude(actor: user)
    end

    it "excludes non trial registrations" do
      user.update!(onboarding_status_registration_type: 'non-trial')
      expect(exp).to exclude(actor: user)
    end

    it "excludes non determined trial registration types" do
      user.update!(onboarding_status_registration_type: nil)
      expect(exp).to exclude(actor: user)
    end

    it "excludes user who isn't signed in" do
      expect(exp).to exclude(actor: "UNIQUE_ID")
    end

    it "excludes not yet created user" do
      expect(exp).to exclude(actor: nil)
    end
  end

  context "for specific onboarding statuses" do
    excluded_roles = described_class::EXCLUDED_ROLES
    excluded_objectives = described_class::EXCLUDED_REGISTRATION_OBJECTIVES

    before do
      user.update!(onboarding_status_registration_type: 'trial')
    end

    excluded_roles.each do |role_value|
      role_name = ::UserDetail.onboarding_status_roles.key(role_value)

      it "excludes #{role_name} role" do
        user.update!(onboarding_status_role: role_value)

        expect(exp).to exclude(actor: user)
      end
    end

    excluded_objectives.each do |objective_value|
      objective_name = ::UserDetail.onboarding_status_registration_objectives.key(objective_value)

      it "excludes #{objective_name} registration objective" do
        user.update!(onboarding_status_registration_objective: objective_value)

        expect(exp).to exclude(actor: user)
      end
    end

    it "includes non specified roles" do
      role_value = ::UserDetail.onboarding_status_roles['software_developer']
      user.update!(onboarding_status_role: role_value)

      expect(exp).not_to exclude(actor: user)
    end

    it "includes non specified registration objectives" do
      objective_value = ::UserDetail.onboarding_status_registration_objectives['move_repository']
      user.update!(onboarding_status_registration_objective: objective_value)

      expect(exp).not_to exclude(actor: user)
    end
  end
end
