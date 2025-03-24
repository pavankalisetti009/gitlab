# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::ScheduleWorker, feature_category: :vulnerability_management do
  describe '#perform' do
    let(:worker) { described_class.new }

    let_it_be(:group_1) { create(:group) }
    let_it_be(:group_2) { create(:group) }
    let_it_be(:group_3) { create(:group) }
    let_it_be(:group_4) { create(:group) }
    let_it_be(:project_with_vulnerabilities_1) { create(:project, group: group_1) }
    let_it_be(:project_with_vulnerabilities_2) { create(:project, group: group_2) }
    let_it_be(:project_with_vulnerabilities_3) { create(:project, group: group_3) }
    let_it_be(:project_without_vulnerabilities) { create(:project, group: group_4) }

    subject(:schedule) { worker.perform }

    around do |example|
      travel_to('2024-01-01') { example.run }
    end

    before do
      project_with_vulnerabilities_1.project_setting.update!(has_vulnerabilities: true)
      project_with_vulnerabilities_2.project_setting.update!(has_vulnerabilities: true)
      project_with_vulnerabilities_3.project_setting.update!(has_vulnerabilities: true)

      stub_feature_flags(vulnerability_archival: [group_2, group_3, group_4])

      stub_const("#{described_class}::BATCH_SIZE", 1)

      allow(Vulnerabilities::Archival::ArchiveWorker).to receive(:bulk_perform_in)
    end

    it 'schedules the archival only for the feature enabled projects with vulnerabilities', :aggregate_failures do
      schedule

      expect(Vulnerabilities::Archival::ArchiveWorker).to have_received(:bulk_perform_in).twice

      expect(Vulnerabilities::Archival::ArchiveWorker)
        .to have_received(:bulk_perform_in).with(30, [[project_with_vulnerabilities_2.id, '2023-01-01']])

      expect(Vulnerabilities::Archival::ArchiveWorker)
        .to have_received(:bulk_perform_in).with(60, [[project_with_vulnerabilities_3.id, '2023-01-01']])
    end
  end
end
