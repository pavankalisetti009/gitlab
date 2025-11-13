# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ApprovalSettings, feature_category: :security_policy_management do
  describe '#prevent_approval_by_author' do
    it 'returns the prevent_approval_by_author value' do
      approval_settings = described_class.new({ prevent_approval_by_author: true })
      expect(approval_settings.prevent_approval_by_author).to be true
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.prevent_approval_by_author).to be_nil
      end
    end
  end

  describe '#prevent_approval_by_commit_author' do
    it 'returns the prevent_approval_by_commit_author value' do
      approval_settings = described_class.new({ prevent_approval_by_commit_author: false })
      expect(approval_settings.prevent_approval_by_commit_author).to be false
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.prevent_approval_by_commit_author).to be_nil
      end
    end
  end

  describe '#remove_approvals_with_new_commit' do
    it 'returns the remove_approvals_with_new_commit value' do
      approval_settings = described_class.new({ remove_approvals_with_new_commit: true })
      expect(approval_settings.remove_approvals_with_new_commit).to be true
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.remove_approvals_with_new_commit).to be_nil
      end
    end
  end

  describe '#require_password_to_approve' do
    it 'returns the require_password_to_approve value' do
      approval_settings = described_class.new({ require_password_to_approve: true })
      expect(approval_settings.require_password_to_approve).to be true
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.require_password_to_approve).to be_nil
      end
    end
  end

  describe '#block_branch_modification' do
    it 'returns the block_branch_modification value' do
      approval_settings = described_class.new({ block_branch_modification: true })
      expect(approval_settings.block_branch_modification).to be true
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.block_branch_modification).to be_nil
      end
    end
  end

  describe '#prevent_pushing_and_force_pushing' do
    it 'returns the prevent_pushing_and_force_pushing value' do
      approval_settings = described_class.new({ prevent_pushing_and_force_pushing: true })
      expect(approval_settings.prevent_pushing_and_force_pushing).to be true
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.prevent_pushing_and_force_pushing).to be_nil
      end
    end
  end

  describe '#block_group_branch_modification' do
    context 'when block_group_branch_modification is present' do
      it 'returns the block_group_branch_modification hash' do
        approval_settings = described_class.new({ block_group_branch_modification: { enabled: true } })
        expect(approval_settings.block_group_branch_modification).to eq({ enabled: true })
      end
    end

    context 'when block_group_branch_modification is not present' do
      it 'returns an empty hash' do
        approval_settings = described_class.new({})
        expect(approval_settings.block_group_branch_modification).to eq({})
      end
    end
  end
end
