# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Concerns::ResourceFinder, feature_category: :mcp_server do
  let(:test_class) do
    Class.new do
      include Mcp::Tools::Concerns::ResourceFinder

      attr_accessor :current_user

      def initialize(user = nil)
        @current_user = user
      end

      def test_find_work_item_in_parent(parent, iid)
        find_work_item_in_parent(parent, iid)
      end
    end
  end

  describe '#find_work_item_in_parent' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:group_work_item) { create(:work_item, :epic, namespace: group, iid: 123) }
    let(:service) { test_class.new(user) }

    before_all do
      group.add_developer(user)
    end

    context 'with group parent (epic)' do
      it 'finds work item by iid' do
        stub_licensed_features(epics: true)

        result = service.test_find_work_item_in_parent(group, group_work_item.iid)
        expect(result).to eq(group_work_item)
      end

      it 'raises error when work item not found' do
        expect { service.test_find_work_item_in_parent(group, 99999) }
          .to raise_error(ArgumentError, 'Work item #99999 not found')
      end
    end
  end
end
