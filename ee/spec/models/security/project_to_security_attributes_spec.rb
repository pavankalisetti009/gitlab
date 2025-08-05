# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectToSecurityAttribute, feature_category: :security_asset_inventories do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:category) { create(:security_category, namespace: root_group) }
  let_it_be(:attribute) { create(:security_attribute, security_category: category, namespace: root_group) }

  describe 'associations' do
    it { is_expected.to belong_to(:project).required }
    it { is_expected.to belong_to(:security_attribute).class_name("Security::Attribute").required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:traversal_ids) }

    context 'when validating uniqueness of name scoped to project' do
      let_it_be(:project) { create(:project) }

      subject { build(:project_to_security_attribute, project: project, security_attribute: attribute) }

      it { is_expected.to validate_uniqueness_of(:security_attribute_id).scoped_to(:project_id) }
    end
  end

  context 'with loose foreign key on project_to_security_attributes.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:project_to_security_attribute, project: parent, security_attribute: attribute) }
    end
  end
end
