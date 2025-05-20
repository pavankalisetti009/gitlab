import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsTableRows from 'ee/ai/shared/feature_settings/feature_settings_table_rows.vue';
import ModelSelector from 'ee/ai/model_selection/model_selector.vue';
import { mockCodeSuggestionsFeatureSettings } from './mock_data';

describe('FeatureSettingsTableRows', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(FeatureSettingsTableRows, {
      propsData: {
        aiFeatureSettings: mockCodeSuggestionsFeatureSettings,
        isLoading: false,
        ...props,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableRows = () => findTable().findAllComponents('tbody > tr');
  const findRowFeatureNameByIdx = (idx) => findTableRows().at(idx).findAll('td').at(0);
  const findModelSelectorByIdx = (idx) => findTableRows().at(idx).findComponent(ModelSelector);
  const findFeatureSettingsTableRows = () => wrapper.findComponent(FeatureSettingsTableRows);
  const findLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettingsTableRows().exists()).toBe(true);
  });

  it('renders skeleton loaders when loading', () => {
    createComponent({ isLoading: true });

    expect(findLoaders().exists()).toBe(true);
  });

  describe('rows', () => {
    it('renders row data for each feature setting', () => {
      createComponent();

      expect(findTableRows().length).toBe(mockCodeSuggestionsFeatureSettings.length);
    });

    it('renders the feature name', () => {
      createComponent();

      expect(findRowFeatureNameByIdx(0).text()).toBe('Code Completion');
      expect(findRowFeatureNameByIdx(1).text()).toBe('Code Generation');
    });

    it('renders the model select dropdown and passes the correct prop', () => {
      createComponent();

      expect(findModelSelectorByIdx(0).props('aiFeatureSetting')).toEqual(
        mockCodeSuggestionsFeatureSettings[0],
      );
      expect(findModelSelectorByIdx(1).props('aiFeatureSetting')).toEqual(
        mockCodeSuggestionsFeatureSettings[1],
      );
    });
  });
});
