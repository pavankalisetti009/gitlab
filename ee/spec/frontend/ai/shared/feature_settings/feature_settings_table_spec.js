import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsTable from 'ee/ai/shared/feature_settings/feature_settings_table.vue';
import FeatureSettingsBlock from 'ee/ai/shared/feature_settings/feature_settings_block.vue';
import {
  mockCodeSuggestionsFeatureSettings,
  mockDuoChatFeatureSettings,
  mockOtherDuoFeaturesSettings,
  mockAiFeatureSettings,
} from './mock_data';

describe('FeatureSettingsTable', () => {
  let wrapper;

  const createComponent = ({ props = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(FeatureSettingsTable, {
      propsData: {
        featureSettings: mockAiFeatureSettings,
        isLoading: false,
        ...props,
      },
      stubs: { ...stubs },
    });
  };

  const findFeatureSettingsTable = () => wrapper.findComponent(FeatureSettingsTable);
  const findDuoChatTableRows = () => wrapper.findByTestId('duo-chat-table-rows');
  const findCodeSuggestionsTableRows = () => wrapper.findByTestId('code-suggestions-table-rows');
  const findOtherDuoFeaturesTableRows = () => wrapper.findByTestId('other-duo-features-table-rows');
  const findAllSettingsBlock = () => wrapper.findAllComponents(FeatureSettingsBlock);
  const findAllSettingsDescriptions = () => wrapper.findAllComponents(GlSprintf);

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettingsTable().exists()).toBe(true);
  });

  describe('when feature settings data is loading', () => {
    it('passes the correct loading state to FeatureSettingsTableRows', () => {
      createComponent({ props: { isLoading: true } });

      expect(findCodeSuggestionsTableRows().props('isLoading')).toBe(true);
      expect(findDuoChatTableRows().props('isLoading')).toBe(true);
      expect(findOtherDuoFeaturesTableRows().props('isLoading')).toBe(true);
    });
  });

  it('renders Code Suggestions section', () => {
    createComponent();

    expect(findAllSettingsBlock().at(0).props('title')).toBe('Code Suggestions');
    expect(findAllSettingsDescriptions().at(0).attributes('message')).toContain(
      'Assists developers by providing real-time code completions',
    );
    expect(findCodeSuggestionsTableRows().props('aiFeatureSettings')).toEqual(
      mockCodeSuggestionsFeatureSettings,
    );
  });

  it('renders Duo Chat section', () => {
    createComponent();

    expect(findAllSettingsBlock().at(1).props('title')).toBe('GitLab Duo Chat');
    expect(findAllSettingsDescriptions().at(1).attributes('message')).toContain(
      'An AI assistant that provides real-time guidance',
    );
    expect(findDuoChatTableRows().props('aiFeatureSettings')).toEqual(mockDuoChatFeatureSettings);
  });

  describe('Other GitLab Duo features section', () => {
    it('renders section when there are feature settings to show', () => {
      createComponent();

      expect(findAllSettingsBlock()).toHaveLength(3);
      expect(findAllSettingsBlock().at(2).props('title')).toBe('Other GitLab Duo features');
      expect(findOtherDuoFeaturesTableRows().exists()).toBe(true);
      expect(findOtherDuoFeaturesTableRows().props('aiFeatureSettings')).toEqual(
        mockOtherDuoFeaturesSettings,
      );
    });
  });
});
