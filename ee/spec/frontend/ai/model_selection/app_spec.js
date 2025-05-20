import ModelSelectionApp from 'ee/ai/model_selection/app.vue';
import FeatureSettingsTable from 'ee/ai/shared/feature_settings/feature_settings_table.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockFeatureSettings } from '../shared/feature_settings/mock_data';

describe('ModelSelectionApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(ModelSelectionApp, {});
  };

  const findTitle = () => wrapper.findByTestId('model-selection-title');
  const findFeatureSettingsTable = () => wrapper.findComponent(FeatureSettingsTable);

  it('has a title', () => {
    createComponent();

    expect(findTitle().text()).toBe('Model Selection');
  });

  it('has a description', () => {
    createComponent();

    expect(wrapper.text()).toMatch(
      'Manage GitLab Duo by configuring and assigning models to AI-native features.',
    );
  });

  it('renders feature settings table and passes the correct props', () => {
    createComponent();

    expect(findFeatureSettingsTable().props('isLoading')).toBe(false);
    expect(findFeatureSettingsTable().props('featureSettings')).toBe(mockFeatureSettings);
  });
});
