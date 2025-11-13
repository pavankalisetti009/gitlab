# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyScope, feature_category: :security_policy_management do
  describe '#compliance_frameworks' do
    context 'when compliance_frameworks is present' do
      let(:policy_scope_data) { { compliance_frameworks: [{ id: 1 }, { id: 2 }] } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the compliance_frameworks array' do
        expect(policy_scope.compliance_frameworks).to match_array([{ id: 1 }, { id: 2 }])
      end
    end

    context 'when compliance_frameworks is not present' do
      let(:policy_scope_data) { {} }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns an empty array' do
        expect(policy_scope.compliance_frameworks).to be_empty
      end
    end
  end

  describe '#projects' do
    context 'when projects is present' do
      let(:policy_scope_data) { { projects: { including: [{ id: 1 }, { id: 2 }, { id: 3 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the projects hash' do
        expect(policy_scope.projects).to eq({ including: [{ id: 1 }, { id: 2 }, { id: 3 }] })
      end
    end

    context 'when projects has excluding' do
      let(:policy_scope_data) { { projects: { excluding: [{ id: 4 }, { id: 5 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the projects hash with excluding' do
        expect(policy_scope.projects).to eq({ excluding: [{ id: 4 }, { id: 5 }] })
      end
    end

    context 'when projects has both including and excluding' do
      let(:policy_scope_data) { { projects: { including: [{ id: 1 }, { id: 2 }], excluding: [{ id: 3 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the projects hash with both including and excluding' do
        expect(policy_scope.projects).to eq({ including: [{ id: 1 }, { id: 2 }], excluding: [{ id: 3 }] })
      end
    end

    context 'when projects is not present' do
      let(:policy_scope_data) { {} }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns an empty hash' do
        expect(policy_scope.projects).to be_empty
      end
    end
  end

  describe '#groups' do
    context 'when groups is present' do
      let(:policy_scope_data) { { groups: { including: [{ id: 4 }, { id: 5 }, { id: 6 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the groups hash' do
        expect(policy_scope.groups).to eq({ including: [{ id: 4 }, { id: 5 }, { id: 6 }] })
      end
    end

    context 'when groups has excluding' do
      let(:policy_scope_data) { { groups: { excluding: [{ id: 7 }, { id: 8 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the groups hash with excluding' do
        expect(policy_scope.groups).to eq({ excluding: [{ id: 7 }, { id: 8 }] })
      end
    end

    context 'when groups has both including and excluding' do
      let(:policy_scope_data) { { groups: { including: [{ id: 4 }, { id: 5 }], excluding: [{ id: 6 }] } } }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns the groups hash with both including and excluding' do
        expect(policy_scope.groups).to eq({ including: [{ id: 4 }, { id: 5 }], excluding: [{ id: 6 }] })
      end
    end

    context 'when groups is not present' do
      let(:policy_scope_data) { {} }
      let(:policy_scope) { described_class.new(policy_scope_data) }

      it 'returns an empty hash' do
        expect(policy_scope.groups).to be_empty
      end
    end
  end
end
