import { mountExtended } from 'helpers/vue_test_utils_helper';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import ModelSelectionFeatureSettingsTable from 'ee/ai/model_selection/feature_settings_table.vue';
import ModelSelector from 'ee/ai/model_selection/model_selector.vue';
import ModelSelectionBatchSettingsUpdater from 'ee/ai/model_selection/batch_settings_updater.vue';
import ModelHeader from 'ee/ai/shared/feature_settings/model_header.vue';

import { mockCodeSuggestionsFeatureSettings } from './mock_data';

describe('ModelSelectionFeatureSettingsTable', () => {
  let wrapper;
  const groupId = 'gid://gitlab/Group/1';

  const createComponent = (props = {}) => {
    wrapper = mountExtended(ModelSelectionFeatureSettingsTable, {
      propsData: {
        featureSettings: mockCodeSuggestionsFeatureSettings,
        isLoading: false,
        ...props,
      },
      provide: {
        groupId,
      },
    });
  };

  const findFeatureSettingsTable = () => wrapper.findComponent(ModelSelectionFeatureSettingsTable);
  const findTableRows = () => findFeatureSettingsTable().findAllComponents('tbody > tr');
  const findTableHeaders = () => findFeatureSettingsTable().findAllComponents('thead > tr');
  const findRowFeatureNameByIdx = (idx) => findTableRows().at(idx).findAll('td').at(0);
  const findModelSelectorByIdx = (idx) => findTableRows().at(idx).findComponent(ModelSelector);
  const findModelBatchSettingsUpdaterByIdx = (idx) =>
    findTableRows().at(idx).findComponent(ModelSelectionBatchSettingsUpdater);
  const findModelHeaderTooltip = () => wrapper.findByTestId('model-header-tooltip');
  const findHelpPageLink = () => wrapper.findComponent(HelpPageLink);

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettingsTable().exists()).toBe(true);
  });

  describe('rows', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders row data for each feature setting', () => {
      expect(findTableRows()).toHaveLength(mockCodeSuggestionsFeatureSettings.length);
    });

    it('renders model header', () => {
      const modelHeaderCell = findTableHeaders().at(0).findAll('th').at(1);
      const modelHeader = modelHeaderCell.findComponent(ModelHeader);

      expect(modelHeader.props('label')).toEqual('Model');

      expect(findModelHeaderTooltip().text()).toContain(
        'Select a model version for full control of your configuration, or GitLab Default for GitLab to manage the selection.',
      );
      expect(findHelpPageLink().attributes('href')).toBe('/help/user/gitlab_duo/model_selection');
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
      it('renders the model batch settings updater', () => {
        [0, 1].forEach((idx) => {
          expect(findModelBatchSettingsUpdaterByIdx(idx).props()).toEqual({
            selectedFeatureSetting: mockCodeSuggestionsFeatureSettings[idx],
            aiFeatureSettings: mockCodeSuggestionsFeatureSettings,
          });
        });
      });

      it('does not render the batch settings updater when there is a single feature', () => {
        const featureSetting = mockCodeSuggestionsFeatureSettings[0];

        createComponent({ featureSettings: [featureSetting] });

        expect(findModelBatchSettingsUpdaterByIdx(0).exists()).toBe(false);
      });

      it('handles update-batch-saving-state event correctly', () => {
        findModelBatchSettingsUpdaterByIdx(0).vm.$emit('update-batch-saving-state', true);

        expect(wrapper.vm.batchUpdateIsSaving).toBe(true);
      });
    });
  });
});
