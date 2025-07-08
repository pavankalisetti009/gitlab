import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsTableRows from 'ee/ai/shared/feature_settings/feature_settings_table_rows.vue';
import ModelSelector from 'ee/ai/model_selection/model_selector.vue';
import ModelSelectionBatchSettingsUpdater from 'ee/ai/model_selection/batch_settings_updater.vue';
import { mockCodeSuggestionsFeatureSettings } from './mock_data';

describe('FeatureSettingsTableRows', () => {
  let wrapper;

  const groupId = 'gid://gitlab/Group/1';
  const createComponent = (props = {}) => {
    wrapper = mountExtended(FeatureSettingsTableRows, {
      propsData: {
        aiFeatureSettings: mockCodeSuggestionsFeatureSettings,
        isLoading: false,
        ...props,
      },
      provide: {
        groupId,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableRows = () => findTable().findAllComponents('tbody > tr');
  const findRowFeatureNameByIdx = (idx) => findTableRows().at(idx).findAll('td').at(0);
  const findModelSelectorByIdx = (idx) => findTableRows().at(idx).findComponent(ModelSelector);
  const findModelBatchSettingsUpdaterByIdx = (idx) =>
    findTableRows().at(idx).findComponent(ModelSelectionBatchSettingsUpdater);
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
    beforeEach(() => {
      createComponent();
    });

    it('renders row data for each feature setting', () => {
      expect(findTableRows().length).toBe(mockCodeSuggestionsFeatureSettings.length);
    });

    it('renders the feature name', () => {
      expect(findRowFeatureNameByIdx(0).text()).toBe('Code Completion');
      expect(findRowFeatureNameByIdx(1).text()).toBe('Code Generation');
    });

    it('renders the model select dropdown and passes the correct props', () => {
      [0, 1].forEach((idx) => {
        expect(findModelSelectorByIdx(idx).props()).toEqual({
          aiFeatureSetting: mockCodeSuggestionsFeatureSettings[idx],
          batchUpdateIsSaving: false,
        });
      });
    });

    describe('model batch settings updater', () => {
      it('renders the batch settings updater when there are multiple features', () => {
        [0, 1].forEach((idx) => {
          expect(findModelBatchSettingsUpdaterByIdx(idx).props()).toEqual({
            selectedFeatureSetting: mockCodeSuggestionsFeatureSettings[idx],
            aiFeatureSettings: mockCodeSuggestionsFeatureSettings,
          });
        });
      });

      it('does not render the batch settings updater when there is a single feature', () => {
        const featureSetting = mockCodeSuggestionsFeatureSettings[0];

        createComponent({ aiFeatureSettings: [featureSetting] });

        expect(findModelBatchSettingsUpdaterByIdx(0).exists()).toBe(false);
      });

      it('handles update-batch-saving-state event correctly', () => {
        findModelBatchSettingsUpdaterByIdx(0).vm.$emit('update-batch-saving-state', true);

        expect(wrapper.vm.batchUpdateIsSaving).toBe(true);
      });
    });
  });
});
