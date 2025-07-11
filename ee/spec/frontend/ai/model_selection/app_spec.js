import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlExperimentBadge } from '@gitlab/ui';
import { createAlert } from '~/alert';
import ModelSelectionApp from 'ee/ai/model_selection/app.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import FeatureSettingsTable from 'ee/ai/shared/feature_settings/feature_settings_table.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import aiNamespaceFeatureSettingsQuery from 'ee/ai/model_selection/graphql/get_ai_namepace_feature_settings.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { mockAiFeatureSettings } from '../shared/feature_settings/mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('ModelSelectionApp', () => {
  let wrapper;

  const groupId = 'gid://gitlab/Group/1';
  const getAiNamespaceFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiModelSelectionNamespaceSettings: {
        nodes: mockAiFeatureSettings,
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [
      [aiNamespaceFeatureSettingsQuery, getAiNamespaceFeatureSettingsSuccessHandler],
    ],
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = shallowMountExtended(ModelSelectionApp, {
      apolloProvider: mockApollo,
      provide: {
        groupId,
      },
    });
  };

  const findTitle = () => wrapper.findByTestId('model-selection-title');
  const findBetaBadge = () => wrapper.findComponent(GlExperimentBadge);
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

  it('has a beta badge', () => {
    createComponent();

    expect(findBetaBadge().props('type')).toBe('beta');
  });

  it('passes the correct loading state to `FeatureSettingsTable` when data is loading', () => {
    createComponent();

    expect(findFeatureSettingsTable().props('isLoading')).toBe(true);
  });

  it('renders feature settings table and passes the correct props when the query succeeds', async () => {
    createComponent();

    await waitForPromises();

    expect(findFeatureSettingsTable().props('isLoading')).toBe(false);
    expect(findFeatureSettingsTable().props('featureSettings')).toEqual(mockAiFeatureSettings);
  });

  it('displays an error message when the query throws an error', async () => {
    createComponent({
      apolloHandlers: [[aiNamespaceFeatureSettingsQuery, jest.fn().mockRejectedValue('ERROR')]],
    });

    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith(
      expect.objectContaining({
        message: 'An error occurred while loading the AI feature settings. Please try again.',
      }),
    );
  });
});
