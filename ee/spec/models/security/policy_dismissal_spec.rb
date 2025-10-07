# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyDismissal, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to belong_to(:merge_request).required }
    it { is_expected.to belong_to(:security_policy).required }
    it { is_expected.to belong_to(:user).optional }
  end

  describe 'validations' do
    subject(:policy_dismissal) { create(:policy_dismissal) }

    it { is_expected.to allow_value(nil).for(:security_findings_uuids) }
    it { is_expected.to validate_length_of(:comment).is_at_most(255).allow_nil }

    it { is_expected.to(validate_uniqueness_of(:merge_request_id).scoped_to(%i[security_policy_id])) }

    context 'when validating dismissal_types' do
      it 'is invalid if empty' do
        policy_dismissal.dismissal_types = []
        expect(policy_dismissal).not_to be_valid
        expect(policy_dismissal.errors[:dismissal_types]).to include(/must be an array with allowed values/)
      end

      it 'is invalid if includes unknown value' do
        policy_dismissal.dismissal_types = described_class::DISMISSAL_TYPES.values + [999]
        expect(policy_dismissal).not_to be_valid
        expect(policy_dismissal.errors[:dismissal_types]).to include(/must be an array with allowed values/)
      end

      it 'is valid if all values are allowed' do
        policy_dismissal.dismissal_types = described_class::DISMISSAL_TYPES.values.sample(2)
        expect(policy_dismissal).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.for_projects' do
      subject(:policy_dismissal_for_projects) { described_class.for_projects(projects) }

      let_it_be(:project) { create(:project) }
      let_it_be(:security_policy_dismissal) { create(:policy_dismissal, project: project) }
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_security_policy_dismissal) { create(:policy_dismissal, project: other_project) }

      context 'when querying for a single project' do
        let(:projects) { [project] }

        it 'returns dismissals for the given project' do
          expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal)
        end

        context 'with multiple dismissals for the same project' do
          let_it_be(:second_security_policy_dismissal) { create(:policy_dismissal, project: project) }

          it 'returns dismissals for the given project' do
            expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal,
              second_security_policy_dismissal)
          end
        end
      end

      context 'when querying for multiple projects' do
        let_it_be(:third_project) { create(:project) }
        let_it_be(:third_security_policy_dismissal) { create(:policy_dismissal, project: third_project) }

        let(:projects) { [project, other_project] }

        it 'returns dismissals for the given projects' do
          expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal,
            other_security_policy_dismissal)
        end

        context 'with multiple dismissals for the same project' do
          let_it_be(:second_security_policy_dismissal_project) { create(:policy_dismissal, project: project) }
          let_it_be(:second_security_policy_dismissal_other_project) do
            create(:policy_dismissal, project: other_project)
          end

          it 'returns dismissals for the given projects' do
            expect(policy_dismissal_for_projects).to contain_exactly(security_policy_dismissal,
              other_security_policy_dismissal,
              second_security_policy_dismissal_project,
              second_security_policy_dismissal_other_project)
          end
        end
      end
    end

    describe '.for_security_findings_uuids' do
      let_it_be(:dismissed_finding) { SecureRandom.uuid }
      let_it_be(:non_dismissed_finding) { SecureRandom.uuid }
      let_it_be(:dismissed_findings) { [dismissed_finding] }
      let_it_be(:uuids) { [dismissed_finding] }

      let_it_be(:security_policy_dismissal) { create(:policy_dismissal, security_findings_uuids: dismissed_findings) }

      subject(:policy_dismissal_for_uuids) { described_class.for_security_findings_uuids(uuids) }

      context 'when querying for a single UUID' do
        it 'returns dismissals that contain the finding UUID' do
          expect(policy_dismissal_for_uuids).to contain_exactly(security_policy_dismissal)
        end
      end

      context 'when querying for multiple UUIDs' do
        let_it_be(:other_dismissed_finding) { SecureRandom.uuid }
        let_it_be(:uuids) { [dismissed_finding, other_dismissed_finding] }

        context 'when the UUIDs were dismissed by the same policy' do
          let_it_be(:dismissed_findings) { [dismissed_finding, other_dismissed_finding] }

          it 'returns dismissals that contain the vulnerability finding UUIDs' do
            expect(policy_dismissal_for_uuids).to contain_exactly(security_policy_dismissal)
          end
        end

        context 'when the UUIDs were dismissed by different policies' do
          let_it_be(:other_security_policy_dismissal) do
            create(:policy_dismissal, security_findings_uuids: [other_dismissed_finding])
          end

          it 'returns dismissals that contain the vulnerability finding UUIDs' do
            expect(policy_dismissal_for_uuids).to contain_exactly(security_policy_dismissal,
              other_security_policy_dismissal)
          end
        end
      end
    end
  end
end
