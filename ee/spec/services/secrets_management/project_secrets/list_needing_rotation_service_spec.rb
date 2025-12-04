# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecrets::ListNeedingRotationService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }

  let!(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:service) { described_class.new(project, user) }

  describe '#execute', :aggregate_failures do
    let(:user) { create(:user, owner_of: project) }

    subject(:result) { service.execute }

    context 'when secrets manager is active and user is owner' do
      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      context 'when there are no secrets' do
        it 'returns an empty array' do
          expect(result).to be_success
          expect(result.payload[:project_secrets]).to eq([])
        end
      end

      context 'when there are secrets but none need rotation' do
        before do
          # Create secret with rotation info in "OK" status
          create_project_secret(
            user: user,
            project: project,
            name: 'OK_SECRET',
            description: 'Secret with OK rotation status',
            branch: 'main',
            environment: 'production',
            value: 'secret-value',
            rotation_interval_days: 365 # Far in the future
          )
        end

        it 'returns an empty array' do
          expect(result).to be_success
          expect(result.payload[:project_secrets]).to eq([])
        end
      end

      context 'when there are secrets needing rotation' do
        let!(:overdue_secret_old) do
          create_project_secret(
            user: user,
            project: project,
            name: 'OVERDUE_OLD',
            description: 'Old overdue secret',
            branch: 'main',
            environment: 'production',
            value: 'old-secret-value',
            rotation_interval_days: 30
          )
        end

        let!(:approaching_secret_soon) do
          create_project_secret(
            user: user,
            project: project,
            name: 'APPROACHING_SOON',
            description: 'Approaching secret due soon',
            branch: 'staging',
            environment: 'staging',
            value: 'approaching-soon-value',
            rotation_interval_days: 30
          )
        end

        let!(:overdue_secret_new) do
          create_project_secret(
            user: user,
            project: project,
            name: 'OVERDUE_NEW',
            description: 'New overdue secret',
            branch: 'main',
            environment: 'production',
            value: 'new-secret-value',
            rotation_interval_days: 30
          )
        end

        let!(:ok_secret) do
          create_project_secret(
            user: user,
            project: project,
            name: 'OK_SECRET',
            description: 'Secret with OK status',
            branch: 'main',
            environment: 'production',
            value: 'ok-secret-value',
            rotation_interval_days: 365
          )
        end

        let!(:non_rotating_secret) do
          create_project_secret(
            user: user,
            project: project,
            name: 'NON_ROTATING_SECRET',
            description: 'Secret with no rotation',
            branch: 'main',
            environment: 'production',
            value: 'forever-secret-value',
            rotation_interval_days: nil
          )
        end

        let!(:approaching_secret_later) do
          create_project_secret(
            user: user,
            project: project,
            name: 'APPROACHING_LATER',
            description: 'Approaching secret due later',
            branch: 'staging',
            environment: 'staging',
            value: 'approaching-later-value',
            rotation_interval_days: 30
          )
        end

        before do
          # Simulate different creation times by updating created_at directly
          overdue_secret_old.rotation_info.update_columns(
            created_at: 3.months.ago,
            last_reminder_at: 1.day.ago # Make it overdue
          )

          overdue_secret_new.rotation_info.update_columns(
            created_at: 1.week.ago,
            last_reminder_at: 1.day.ago # Make it overdue
          )

          # Make approaching secrets with different due dates
          approaching_secret_soon.rotation_info.update_columns(
            next_reminder_at: 2.days.from_now # Due sooner (approaching)
          )

          approaching_secret_later.rotation_info.update_columns(
            next_reminder_at: 6.days.from_now # Due later (approaching)
          )
        end

        it 'returns only secrets needing rotation in correct priority order' do
          expect(result).to be_success

          secrets = result.payload[:project_secrets]

          # Verify order: overdue secrets first (oldest first), then approaching (earliest due first)
          expect(secrets.map(&:name)).to eq([
            'OVERDUE_OLD',      # Oldest overdue (created 3 months ago)
            'OVERDUE_NEW',      # Newer overdue (created 1 week ago)
            'APPROACHING_SOON', # Approaching due sooner
            'APPROACHING_LATER' # Approaching due later
          ])
        end
      end
    end

    context 'when user is a developer and no permissions' do
      let(:user) { create(:user, developer_of: project) }

      it 'returns an error' do
        provision_project_secrets_manager(secrets_manager, user)
        expect(result).to be_error
        expect(result.message).to eq("1 error occurred:\n\t* permission denied\n\n")
      end
    end

    context 'when user is a developer and has proper permissions' do
      let(:user) { create(:user, developer_of: project) }

      before do
        provision_project_secrets_manager(secrets_manager, user)
        update_secret_permission(
          user: user, project: project, permissions: %w[read], principal: {
            id: Gitlab::Access.sym_options[:developer], type: 'Role'
          }
        )
      end

      it 'returns success' do
        expect(result).to be_success
        expect(result.payload[:project_secrets]).to eq([])
      end
    end

    context 'when secrets manager is not active' do
      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end
    end
  end
end
