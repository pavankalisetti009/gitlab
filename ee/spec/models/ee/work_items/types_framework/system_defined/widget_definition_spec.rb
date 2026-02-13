# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::TypesFramework::SystemDefined::WidgetDefinition, feature_category: :team_planning do
  describe '.widget_types' do
    subject(:widget_types) { described_class.widget_types }

    it 'includes all EE-specific widget types' do
      ee_widget_types = %w[
        health_status
        weight
        iteration
        progress
        verification_status
        requirement_legacy
        test_reports
        color
        status
        custom_fields
        vulnerabilities
      ]

      expect(widget_types).to include(*ee_widget_types)
    end
  end

  describe '#licensed?' do
    let(:resource_parent) { build(:project) }

    context 'when widget type has a license requirement' do
      shared_examples 'requirements license check' do |widget_type, licence_name, work_item_type_id|
        let(:widget_definition) do
          build(:work_item_system_defined_widget_definition, widget_type: widget_type,
            work_item_type_id: work_item_type_id)
        end

        it "returns true when the requirment license is available" do
          expect(resource_parent).to receive(:licensed_feature_available?)
            .with(licence_name.to_sym)
            .and_return(true)

          expect(widget_definition.licensed?(resource_parent)).to be true
        end

        it 'returns false when requirements license is not available' do
          expect(resource_parent).to receive(:licensed_feature_available?)
            .with(licence_name.to_sym)
            .and_return(false)

          expect(widget_definition.licensed?(resource_parent)).to be false
        end
      end

      it_behaves_like 'requirements license check', 'health_status', 'issuable_health_status', 1 # for issue type
      it_behaves_like 'requirements license check', 'iteration', 'iterations', 1
      it_behaves_like 'requirements license check', 'weight', 'issue_weights', 1
      it_behaves_like 'requirements license check', 'verification_status', 'requirements', 4 # for requirement type
      it_behaves_like 'requirements license check', 'requirement_legacy', 'requirements', 4
      it_behaves_like 'requirements license check', 'test_reports', 'requirements', 4
      it_behaves_like 'requirements license check', 'progress', 'okrs', 6 # for objective type
      it_behaves_like 'requirements license check', 'color', 'epic_colors', 8 # for epic type
      it_behaves_like 'requirements license check', 'custom_fields', 'custom_fields', 1
      it_behaves_like 'requirements license check', 'vulnerabilities', 'security_dashboard', 1
      it_behaves_like 'requirements license check', 'status', 'work_item_status', 1
    end

    context 'when widget type does not have a license requirement' do
      context 'with CE widget types' do
        let(:ce_widget_types) do
          %w[
            assignees
            description
            labels
            milestone
            notes
            hierarchy
          ]
        end

        it 'returns true for all CE widgets without checking license' do
          ce_widget_types.each do |widget_type|
            widget_definition = build(:work_item_system_defined_widget_definition, widget_type: widget_type)

            expect(resource_parent).not_to receive(:licensed_feature_available?)
            expect(widget_definition.licensed?(resource_parent)).to be true
          end
        end
      end
    end

    context 'when resource_parent is nil for a licenced widget' do
      let(:widget_definition) { build(:work_item_system_defined_widget_definition, widget_type: 'iteration') }

      it 'raises an error when trying to check license' do
        expect { widget_definition.licensed?(nil) }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#build_widget' do
    let(:work_item) { build(:work_item) }

    context 'with widget_options' do
      let(:definition) { build(:work_item_system_defined_widget_definition, widget_type: 'weight') }

      it 'passes widget_definition with options to the widget' do
        widget = definition.build_widget(work_item)
        widget_def = widget.instance_variable_get(:@widget_definition)

        expect(widget_def.widget_options).to eq(definition.widget_options)
      end
    end
  end
end
