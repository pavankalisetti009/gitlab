import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsTable from 'ee/ai/shared/feature_settings/feature_settings_table.vue';
import FeatureSettingsBlock from 'ee/ai/shared/feature_settings/feature_settings_block.vue';
import {
  mockCodeSuggestionsFeatureSettings,
  mockDuoChatFeatureSettings,
  mockMergeRequestFeatureSettings,
  mockIssueFeatureSettings,
  mockOtherDuoFeaturesSettings,
  mockAiFeatureSettings,
} from './mock_data';

describe('FeatureSettingsTable', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(FeatureSettingsTable, {
      propsData: {
        featureSettings: mockAiFeatureSettings,
        isLoading: false,
        ...props,
      },
    });
  };

  const findFeatureSettingsTable = () => wrapper.findComponent(FeatureSettingsTable);
  const findAllSettingsBlock = () => wrapper.findAllComponents(FeatureSettingsBlock);
  const findAllSettingsDescriptions = () => wrapper.findAllComponents(GlSprintf);
  const findDuoChatTableRows = () => wrapper.findByTestId('duo-chat-table-rows');
  const findCodeSuggestionsTableRows = () => wrapper.findByTestId('code-suggestions-table-rows');
  const findOtherDuoFeaturesTableRows = () => wrapper.findByTestId('other-duo-features-table-rows');
  const findDuoIssuesTableRows = () => wrapper.findByTestId('duo-issues-table-rows');
  const findDuoMergeRequestTableRows = () => wrapper.findByTestId('duo-merge-requests-table-rows');

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettingsTable().exists()).toBe(true);
  });

  describe('when feature settings data is loading', () => {
    it('passes the correct loading state to `FeatureSettingsTableRows`', () => {
      createComponent({ props: { isLoading: true } });

      expect(findCodeSuggestionsTableRows().props('isLoading')).toBe(true);
      expect(findDuoChatTableRows().props('isLoading')).toBe(true);
      expect(findDuoMergeRequestTableRows().props('isLoading')).toBe(true);
      expect(findDuoIssuesTableRows().props('isLoading')).toBe(true);
      expect(findOtherDuoFeaturesTableRows().props('isLoading')).toBe(true);
    });
  });

  describe('sections', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders Code Suggestions section', () => {
      expect(findAllSettingsBlock().at(0).props('title')).toBe('Code Suggestions');
      expect(findAllSettingsDescriptions().at(0).attributes('message')).toContain(
        'Assists developers by generating and completing code in real-time.',
      );
      expect(findCodeSuggestionsTableRows().props('aiFeatureSettings')).toEqual(
        mockCodeSuggestionsFeatureSettings,
      );
    });

    it('renders Duo Chat section', () => {
      createComponent();

      expect(findAllSettingsBlock().at(1).props('title')).toBe('GitLab Duo Chat');
      expect(findAllSettingsDescriptions().at(1).attributes('message')).toContain(
        'An AI assistant that helps users accelerate software development using real-time conversational AI',
      );
      expect(findDuoChatTableRows().props('aiFeatureSettings')).toEqual(mockDuoChatFeatureSettings);
    });

    it('renders Duo Merge Request section', () => {
      createComponent();

      expect(findAllSettingsBlock().at(2).props('title')).toBe('GitLab Duo for merge requests');
      expect(findAllSettingsDescriptions().at(2).attributes('message')).toContain(
        'AI-native features that help users accomplish tasks during the lifecycle of a merge request.',
      );
      expect(findDuoMergeRequestTableRows().props('aiFeatureSettings')).toEqual(
        mockMergeRequestFeatureSettings,
      );
    });

    it('renders Duo issues section', () => {
      createComponent();

      expect(findAllSettingsBlock().at(3).props('title')).toBe('GitLab Duo for issues');
      expect(findAllSettingsDescriptions().at(3).attributes('message')).toContain(
        'An AI-native feature that generates a summary of discussions on an issue.',
      );
      expect(findDuoIssuesTableRows().props('aiFeatureSettings')).toEqual(mockIssueFeatureSettings);
    });

    it('renders Other GitLab Duo features section', () => {
      createComponent();

      expect(findAllSettingsBlock().at(4).props('title')).toBe('Other GitLab Duo features');
      expect(findAllSettingsDescriptions().at(4).attributes('message')).toContain(
        'AI-native features that support users outside of Chat or Code Suggestions.',
      );
      expect(findOtherDuoFeaturesTableRows().props('aiFeatureSettings')).toEqual(
        mockOtherDuoFeaturesSettings,
      );
    });
  });
});
