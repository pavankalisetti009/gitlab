# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::DirectReassignService, feature_category: :importers do
  describe '.model_list' do
    it 'includes expected models and their attributes' do
      model_list = described_class.model_list

      # EE models
      expect(model_list['ApprovalProjectRulesUser']).to eq(['user_id'])
      expect(model_list['BoardAssignee']).to eq(['assignee_id'])

      # CE models
      expect(model_list['Issue']).to eq(%w[author_id updated_by_id closed_by_id])
      expect(model_list['MergeRequest']).to eq(%w[author_id updated_by_id merge_user_id])
      expect(model_list['Note']).to eq(%w[author_id])
      expect(model_list['Approval']).to eq(['user_id'])
    end
  end
end
