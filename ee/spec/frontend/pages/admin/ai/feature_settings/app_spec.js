import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import FeatureSettingsApp from 'ee/pages/admin/ai/feature_settings/components/app.vue';
import getAiFeatureSettingsQuery from 'ee/pages/admin/ai/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import AiFeatureSettingsTable from 'ee/pages/admin/ai/feature_settings/components/feature_settings_table.vue';
import { createAlert } from '~/alert';
import { mockAiFeatureSettings } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('FeatureSettingsApp', () => {
  let wrapper;

  const getAiFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettings: {
        nodes: mockAiFeatureSettings,
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [[getAiFeatureSettingsQuery, getAiFeatureSettingsSuccessHandler]],
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);
    const newSelfHostedModelPath = '/admin/ai/self_hosted_models/new';

    wrapper = shallowMount(FeatureSettingsApp, {
      apolloProvider: mockApollo,
      propsData: {
        newSelfHostedModelPath,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findAiFeatureSettingsTable = () => wrapper.findComponent(AiFeatureSettingsTable);
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);

  it('has a title', () => {
    const title = wrapper.find('h1');

    expect(title.text()).toBe('AI-powered features');
  });

  it('has a description', () => {
    expect(wrapper.text()).toMatch(
      'Features that can be enabled, disabled, or linked to a cloud-based or self-hosted model.',
    );
  });

  describe('when AI feature settings are loading', () => {
    it('renders skeleton loader', () => {
      expect(findLoader().exists()).toBe(true);
    });
  });

  describe('when the API request is successful', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('renders the feature settings table and passes the correct props', () => {
      expect(findAiFeatureSettingsTable().props('aiFeatureSettings')).toEqual(
        mockAiFeatureSettings,
      );
    });
  });

  describe('when the API request is unsuccessful', () => {
    const getAiFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
      data: {
        aiFeatureSettings: {
          errors: ['An error occured'],
        },
      },
    });

    beforeEach(async () => {
      createComponent({
        apolloHandlers: [[getAiFeatureSettingsQuery, getAiFeatureSettingsErrorHandler]],
      });

      await waitForPromises();
    });

    it('displays an error message', () => {
      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'An error occurred while loading the AI feature settings. Please try again.',
        }),
      );
    });
  });
});
