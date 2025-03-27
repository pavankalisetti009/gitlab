# frozen_string_literal: true

RSpec.shared_examples 'graphql work item type list request spec EE' do
  include GraphqlHelpers

  let(:parent_key) { parent.to_ability_name.to_sym }
  let(:licensed_features) { WorkItems::Type::LICENSED_WIDGETS.keys }
  let(:disabled_features) { [] }
  let(:work_item_type_fields) { 'name widgetDefinitions { type }' }
  let(:returned_widgets) do
    graphql_data_at(parent_key.to_s, 'workItemTypes', 'nodes').flat_map do |type|
      type['widgetDefinitions'].pluck('type')
    end.uniq
  end

  let(:query) do
    graphql_query_for(
      parent_key.to_s,
      { 'fullPath' => parent.full_path },
      query_nodes('WorkItemTypes', work_item_type_fields)
    )
  end

  describe 'allowed statuses' do
    include_context 'with work item types request context EE'

    let(:work_item_types) { graphql_data_at(parent_key, :workItemTypes, :nodes) }
    let_it_be(:names_of_system_defined_statuses) do
      ::WorkItems::Statuses::SystemDefined::Status.all.map(&:name)
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      it 'returns the allowed statuses for supported namespace and work item types' do
        post_graphql(query, current_user: current_user)

        work_item_types.each do |work_item_type|
          work_item_type_name = work_item_type['name']
          status_widgets = work_item_type['widgetDefinitions'].select { |widget| widget['type'] == 'STATUS' }

          status_widgets.each do |widget|
            if widget_available_for?(work_item_type_name: work_item_type_name, widget_type: 'status') &&
                parent&.resource_parent&.root_ancestor&.try(:work_item_status_feature_available?)

              allowed_statuses = widget['allowedStatuses']
              status_names = allowed_statuses.pluck('name')

              expect(allowed_statuses).to all(include('id', 'name', 'iconName', 'color', 'position'))
              expect(status_names).to match_array(names_of_system_defined_statuses)
            else
              expect(widget['allowedStatuses']).to be_empty
            end
          end
        end
      end

      context 'with work_item_status_feature_flag disabled' do
        before do
          stub_feature_flags(work_item_status_feature_flag: false)
          post_graphql(query, current_user: current_user)
        end

        it 'does not return status widget' do
          status_widgets = extract_status_widgets

          expect(status_widgets).to be_empty
        end
      end
    end

    context 'when feature is unlicensed' do
      before do
        stub_licensed_features(work_item_status: false)
        post_graphql(query, current_user: current_user)
      end

      it 'does not return status widget' do
        status_widgets = extract_status_widgets

        expect(status_widgets).to be_empty
      end
    end
  end

  describe 'licensed widgets' do
    before do
      stub_licensed_features(**feature_hash)
      post_graphql(query, current_user: current_user)
    end

    where(feature_widget: WorkItems::Type::LICENSED_WIDGETS.transform_values { |v| Array(v) }.to_a)

    with_them do
      let(:feature) { feature_widget.first }
      let(:widgets) { feature_widget.last }

      context 'when feature is available' do
        it 'returns the associated licensesd widget' do
          widgets.each do |widget|
            expect(returned_widgets).to include(widget_to_enum_string(widget))
          end
        end
      end

      context 'when feature is not available' do
        let(:disabled_features) { [feature] }

        it 'does not return the unlincensed widgets' do
          post_graphql(query, current_user: developer)

          widgets.each do |widget|
            expect(returned_widgets).not_to include(widget_to_enum_string(widget))
          end
        end
      end
    end
  end

  def widget_to_enum_string(widget)
    widget.type.to_s.upcase
  end

  def feature_hash
    available_features = licensed_features - disabled_features

    available_features.index_with { |_| true }.merge(disabled_features.index_with { |_| false })
  end

  def extract_status_widgets
    work_item_types.flat_map do |work_item_type|
      work_item_type['widgetDefinitions'].select { |widget| widget['type'] == 'STATUS' }
    end
  end
end
