# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Scopes, feature_category: :global_search do
  describe '.available_for_context' do
    context 'for global context' do
      it 'includes code scopes with advanced search' do
        allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: nil).and_return(true)
        stub_application_setting(
          global_search_code_enabled: true,
          global_search_wiki_enabled: true,
          global_search_commits_enabled: true
        )
        scopes = described_class.available_for_context(context: :global, requested_search_type: :advanced)

        expect(scopes).to include('blobs', 'commits', 'wiki_blobs', 'notes')
      end

      it 'includes epics with advanced search' do
        allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: nil).and_return(true)
        stub_application_setting(global_search_epics_enabled: true)
        scopes = described_class.available_for_context(context: :global, requested_search_type: :advanced)

        expect(scopes).to include('epics')
      end
    end

    context 'for group context' do
      it 'includes epics with advanced search' do
        allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: nil).and_return(true)
        scopes = described_class.available_for_context(context: :group, requested_search_type: :advanced)

        expect(scopes).to include('epics')
      end

      it 'returns scopes available for group search with advanced' do
        allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: nil).and_return(true)
        scopes = described_class.available_for_context(context: :group, requested_search_type: :advanced)

        expect(scopes).to include('projects', 'issues', 'merge_requests', 'blobs')
        expect(scopes).to include('milestones', 'users')
      end
    end

    context 'for project context' do
      it 'excludes epics in project context' do
        scopes = described_class.available_for_context(context: :project, requested_search_type: :advanced)

        expect(scopes).not_to include('epics')
      end
    end
  end

  describe '.search_type_available?' do
    let(:container) { nil }

    context 'when search_type is :zoekt' do
      it 'checks zoekt availability' do
        allow(Search::Zoekt).to receive(:search?).with(container).and_return(true)
        expect(described_class.send(:search_type_available?, :zoekt, container)).to be true
      end
    end

    context 'when search_type is :advanced' do
      it 'checks elasticsearch availability' do
        allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: container).and_return(true)
        expect(described_class.send(:search_type_available?, :advanced, container)).to be true
      end
    end

    context 'when search_type is :basic' do
      it 'returns true' do
        expect(described_class.send(:search_type_available?, :basic, container)).to be true
      end
    end

    context 'when search_type is unknown' do
      it 'returns false' do
        expect(described_class.send(:search_type_available?, :unknown, container)).to be false
      end
    end
  end

  describe '.valid_definition?' do
    let(:group) { build(:group) }

    context 'for epics scope' do
      let(:scope) { :epics }
      let(:definition) { described_class.scope_definitions[scope] }

      context 'when at group context' do
        let(:context) { :group }

        it 'returns true when licensed and advanced search available' do
          allow(group).to receive(:licensed_feature_available?).with(:epics).and_return(true)
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(true)

          result = described_class.send(:valid_definition?, scope, definition, context, group, :advanced)
          expect(result).to be true
        end

        it 'returns false when not licensed' do
          allow(group).to receive(:licensed_feature_available?).with(:epics).and_return(false)

          result = described_class.send(:valid_definition?, scope, definition, context, group, :advanced)
          expect(result).to be false
        end

        it 'returns true when licensed and basic search requested' do
          allow(group).to receive(:licensed_feature_available?).with(:epics).and_return(true)

          result = described_class.send(:valid_definition?, scope, definition, context, group, :basic)
          expect(result).to be true
        end

        it 'returns true when licensed and zoekt available' do
          allow(group).to receive(:licensed_feature_available?).with(:epics).and_return(true)
          allow(Search::Zoekt).to receive(:search?).with(group).and_return(true)

          result = described_class.send(:valid_definition?, scope, definition, context, group, :zoekt)
          expect(result).to be true
        end
      end

      context 'when at global context' do
        let(:context) { :global }

        it 'returns false when global setting disabled' do
          stub_application_setting(global_search_epics_enabled: false)
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: nil).and_return(true)

          result = described_class.send(:valid_definition?, scope, definition, context, nil, :advanced)
          expect(result).to be false
        end

        it 'returns true when global setting enabled and advanced search available' do
          stub_application_setting(global_search_epics_enabled: true)
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: nil).and_return(true)

          result = described_class.send(:valid_definition?, scope, definition, context, nil, :advanced)
          expect(result).to be true
        end

        it 'returns false when advanced search not available' do
          stub_application_setting(global_search_epics_enabled: true)
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: nil).and_return(false)

          result = described_class.send(:valid_definition?, scope, definition, context, nil, :advanced)
          expect(result).to be false
        end
      end
    end

    context 'for blobs scope with EE search types' do
      let(:scope) { :blobs }
      let(:definition) { described_class.scope_definitions[scope] }

      context 'when at group context with advanced search' do
        it 'returns true and validates in EE' do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(true)
          stub_application_setting(global_search_code_enabled: true)

          result = described_class.send(:valid_definition?, scope, definition, :group, group, :advanced)
          expect(result).to be true
        end

        it 'returns false when global setting disabled' do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(true)
          stub_application_setting(global_search_code_enabled: false)

          result = described_class.send(:valid_definition?, scope, definition, :global, nil, :advanced)
          expect(result).to be false
        end
      end

      context 'when at group context with zoekt' do
        it 'returns true and validates in EE' do
          allow(Search::Zoekt).to receive(:search?).with(group).and_return(true)
          stub_application_setting(global_search_code_enabled: true)

          result = described_class.send(:valid_definition?, scope, definition, :group, group, :zoekt)
          expect(result).to be true
        end
      end

      context 'when at project context with basic search' do
        let(:project) { build(:project) }

        it 'delegates to CE code and returns true' do
          result = described_class.send(:valid_definition?, scope, definition, :project, project, :basic)
          expect(result).to be true
        end
      end

      context 'with no explicit search type' do
        it 'returns true when advanced search is available' do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(true)
          stub_application_setting(global_search_code_enabled: true)

          scopes = described_class.available_for_context(context: :group, container: group)
          expect(scopes).to include('blobs')
        end

        it 'returns true when zoekt is available' do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(false)
          allow(Search::Zoekt).to receive(:search?).with(group).and_return(true)
          stub_application_setting(global_search_code_enabled: true)

          scopes = described_class.available_for_context(context: :group, container: group)
          expect(scopes).to include('blobs')
        end

        it 'delegates to CE when only basic search available' do
          allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: group).and_return(false)
          allow(Search::Zoekt).to receive(:search?).with(group).and_return(false)

          scopes = described_class.available_for_context(context: :group, container: group)
          expect(scopes).not_to include('blobs')
        end

        it 'handles context with no availability' do
          # Create a custom definition with nil availability for the context
          # This tests the safe navigation operator branch in line 87
          custom_definition = {
            label: -> { 'Test' },
            sort: 99,
            availability: {}
          }
          allow(described_class).to receive(:scope_definitions).and_return({
            test_scope: custom_definition
          })

          scopes = described_class.available_for_context(context: :group, container: group)
          expect(scopes).not_to include('test_scope')
        end

        it 'delegates to CE when scope has only basic search type' do
          # Test when ee_search_types is empty (line 91 false branch)
          # This happens when availability has only :basic, no :zoekt or :advanced
          basic_only_definition = {
            label: -> { 'Basic Only' },
            sort: 99,
            availability: {
              group: [:basic]
            }
          }
          allow(described_class).to receive(:scope_definitions).and_return({
            basic_scope: basic_only_definition
          })

          # Should delegate to CE's valid_definition? which will return true for basic
          scopes = described_class.available_for_context(
            context: :group, container: group, requested_search_type: :basic
          )
          expect(scopes).to include('basic_scope')
        end
      end
    end

    context 'for CE scopes with basic search' do
      let(:scope) { :issues }
      let(:definition) { described_class.scope_definitions[scope] }

      it 'delegates to CE code for basic search' do
        result = described_class.send(:valid_definition?, scope, definition, :project, nil, :basic)
        expect(result).to be true
      end

      it 'validates in EE when advanced search requested' do
        allow(Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).with(scope: nil).and_return(true)

        result = described_class.send(:valid_definition?, scope, definition, :global, nil, :advanced)
        expect(result).to be true
      end
    end
  end
end
