import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsTable from 'ee/ai/shared/feature_settings/feature_settings_table.vue';
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
  const findSectionHeaders = () => wrapper.findAll('h2');
  const findSectionDescriptions = () => wrapper.findAllComponents(GlSprintf);

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

    expect(findSectionHeaders().at(0).text()).toBe('Code Suggestions');
    expect(findSectionDescriptions().at(0).attributes('message')).toContain(
      'Assists developers by providing real-time code completions',
    );
    expect(findCodeSuggestionsTableRows().props('aiFeatureSettings')).toEqual(
      mockCodeSuggestionsFeatureSettings,
    );
  });

  it('renders Duo Chat section', () => {
    createComponent();

    expect(findSectionHeaders().at(1).text()).toBe('GitLab Duo Chat');
    expect(findSectionDescriptions().at(1).attributes('message')).toContain(
      'An AI assistant that provides real-time guidance',
    );
    expect(findDuoChatTableRows().props('aiFeatureSettings')).toEqual(mockDuoChatFeatureSettings);
  });

  describe('Other GitLab Duo features section', () => {
    it('renders section when there are feature settings to show', () => {
      createComponent();

      expect(findSectionHeaders()).toHaveLength(3);
      expect(findSectionHeaders().at(2).text()).toBe('Other GitLab Duo features');
      expect(findOtherDuoFeaturesTableRows().exists()).toBe(true);
      expect(findOtherDuoFeaturesTableRows().props('aiFeatureSettings')).toEqual(
        mockOtherDuoFeaturesSettings,
      );
    });
  });
});
