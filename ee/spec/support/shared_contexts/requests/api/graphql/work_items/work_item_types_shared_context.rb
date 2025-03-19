# frozen_string_literal: true

RSpec.shared_context 'with work item types request context EE' do
  include_context 'with work item types request context'

  let(:work_item_type_fields) do
    <<~GRAPHQL
      id
      name
      iconName
      widgetDefinitions {
        type
        ... on WorkItemWidgetDefinitionAssignees {
          canInviteMembers
          allowsMultipleAssignees
        }
        ... on WorkItemWidgetDefinitionHierarchy {
          allowedChildTypes {
            nodes { id name }
          }
          allowedParentTypes {
            nodes { id name }
          }
        }
        ... on WorkItemWidgetDefinitionLabels {
          allowsScopedLabels
        }
        ... on WorkItemWidgetDefinitionWeight {
          editable
          rollUp
        }
        ... on WorkItemWidgetDefinitionStatus {
          allowedStatuses {
            id
            name
            iconName
            color
            position
          }
        }
      }
      supportedConversionTypes {
        id
        name
      }
    GRAPHQL
  end

  let(:widget_attributes) do
    ee_attributes = {
      assignees: {
        'allowsMultipleAssignees' => true
      },
      labels: {
        'allowsScopedLabels' => false
      },
      weight: {
        'editable' => be_boolean,
        'rollUp' => be_boolean
      }
    }

    base_widget_attributes.deep_merge(ee_attributes)
  end

  def widgets_for(work_item_type, resource_parent)
    work_item_type.widget_classes(resource_parent).map do |widget|
      base_attributes = { 'type' => widget.type.to_s.upcase }

      if widget == WorkItems::Widgets::Hierarchy
        next hierarchy_widget_attributes(work_item_type, base_attributes, resource_parent)
      end

      if widget == WorkItems::Widgets::Status
        next status_widget_attributes(work_item_type,
          base_attributes, resource_parent)
      end

      next base_attributes unless widget_attributes[widget.type]

      base_attributes.merge(widget_attributes[widget.type])
    end
  end

  def status_widget_attributes(_work_item_type, base_attributes, resource_parent)
    unless resource_parent&.root_ancestor&.try(:work_item_status_feature_available?)
      return base_attributes.merge({ 'allowedStatuses' => [] })
    end

    statuses = WorkItems::Statuses::SystemDefined::Status.all.map do |status|
      status.attributes.symbolize_keys.merge(iconName: status.icon_name)
    end

    base_attributes.merge({ 'allowedStatuses' => statuses })
  end
end
