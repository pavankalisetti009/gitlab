# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserProjectMemberRole, feature_category: :permissions do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:project).class_name('::Project') }
    it { is_expected.to belong_to(:shared_with_group).class_name('::Group').optional }
    it { is_expected.to belong_to(:member_role) }
  end

  describe 'validations' do
    subject(:user_project_member_role) { build(:user_project_member_role) }

    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:member_role) }
    it { is_expected.to validate_uniqueness_of(:user).scoped_to(%i[project_id shared_with_group_id]) }
  end
end
