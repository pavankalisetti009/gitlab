import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsTableRows from 'ee/pages/admin/ai/duo_self_hosted/feature_settings/components/feature_settings_table_rows.vue';
import FeatureSettingsModelSelector from 'ee/pages/admin/ai/duo_self_hosted/feature_settings/components/feature_settings_model_selector.vue';
import { DUO_MAIN_FEATURES } from 'ee/pages/admin/ai/duo_self_hosted/constants';
import { mockAiFeatureSettings } from './mock_data';

describe('FeatureSettingsTableRows', () => {
  let wrapper;

  const mockCodeSuggestionsFeatureSettings = mockAiFeatureSettings.filter(
    (feature) => feature.mainFeature === DUO_MAIN_FEATURES.CODE_SUGGESTIONS,
  );

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
  const findModelSelectorByIdx = (idx) =>
    findTableRows().at(idx).findComponent(FeatureSettingsModelSelector);
  const findFeatureSettingsTableRows = () => wrapper.findComponent(FeatureSettingsTableRows);
  const findLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);
  const findBetaBadges = () => wrapper.findAllByTestId('feature-beta-badge');
  const findExperimentBadges = () => wrapper.findAllByTestId('feature-experiment-badge');

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

      expect(findRowFeatureNameByIdx(0).text()).toBe('Code Generation');
      expect(findRowFeatureNameByIdx(1).text()).toBe('Code Completion');
    });

    describe('beta features', () => {
      it('renders the beta badge for beta features', () => {
        const betaFeature = mockAiFeatureSettings[3];
        createComponent({ aiFeatureSettings: [betaFeature] });

        expect(findBetaBadges().length).toBe(1);
      });

      it('does not render the beta badge for non-beta features', () => {
        createComponent();

        expect(findBetaBadges().length).toBe(0);
      });
    });

    describe('experiment features', () => {
      it('renders the experiment badge for experiment features', () => {
        const experimentFeature = mockAiFeatureSettings[4];
        createComponent({ aiFeatureSettings: [experimentFeature] });

        expect(findExperimentBadges().length).toBe(1);
      });

      it('does not render the experiment badge for non-experiment features', () => {
        createComponent();

        expect(findExperimentBadges().length).toBe(0);
      });
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
