# frozen_string_literal: true

# Shared examples for GeoNodeStatus project repository replication metrics.
#
# This shared example tests the GeoNodeStatus model's ability to report
# project repository replication statistics on both primary and secondary sites.
#
# Required variables (must be defined in the including spec):
#
# - primary: A Geo primary node instance
#   Example: let(:primary) { create(:geo_node, :primary) }
#
# - secondary: A Geo secondary node instance
#   Example: let(:secondary) { create(:geo_node) }
#
# - project_1, project_2: project instances belonging to the same group
# - project_3: A project instance not belonging to the same group
#
RSpec.shared_examples 'GeoNodeStatus for project repository replication' do
  include ::EE::GeoHelpers

  using RSpec::Parameterized::TableSyntax

  subject(:status) { described_class.current_node_status }

  describe '#projects_count' do
    it 'returns nil on a primary site' do
      stub_current_geo_node(primary)

      expect(status.projects_count).to be_nil
    end

    it 'returns nil on a secondary site' do
      stub_current_geo_node(secondary)

      create(:geo_project_repository_registry, :synced, project: project_1)
      create(:geo_project_repository_registry, project: project_3)

      expect(status.projects_count).to be_nil
    end
  end

  describe '#repositories_count' do
    it 'counts the number of project repositories on a primary site' do
      stub_current_geo_node(primary)

      expect(status.repositories_count).to eq 4
    end

    it 'counts the number of project repository registries on a secondary site' do
      stub_current_geo_node(secondary)

      create(:geo_project_repository_registry, :synced, project: project_1)
      create(:geo_project_repository_registry, project: project_3)

      expect(status.repositories_count).to eq 2
    end
  end

  describe '#repositories_checked_count' do
    before do
      stub_application_setting(repository_checks_enabled: true)
    end

    context 'when current is a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'counts the number of repo checked projects' do
        project_1.update!(last_repository_check_at: 2.minutes.ago)
        project_2.update!(last_repository_check_at: 7.minutes.ago)

        expect(status.repositories_checked_count).to be_nil
      end
    end

    context 'when current is a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'returns nil' do
        project_1.update!(last_repository_check_at: 2.minutes.ago)
        project_2.update!(last_repository_check_at: 7.minutes.ago)

        expect(status.repositories_checked_count).to be_nil
      end
    end
  end

  describe '#repositories_checked_failed_count' do
    before do
      stub_application_setting(repository_checks_enabled: true)
    end

    context 'when current is a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'counts the number of repo check failed projects' do
        project_1.update!(last_repository_check_at: 2.minutes.ago, last_repository_check_failed: true)
        project_2.update!(last_repository_check_at: 7.minutes.ago, last_repository_check_failed: false)

        expect(status.repositories_checked_failed_count).to be_nil
      end
    end

    context 'when current is a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'returns nil' do
        project_1.update!(last_repository_check_at: 2.minutes.ago, last_repository_check_failed: true)
        project_2.update!(last_repository_check_at: 7.minutes.ago, last_repository_check_failed: false)

        expect(status.repositories_checked_failed_count).to be_nil
      end
    end
  end
end
