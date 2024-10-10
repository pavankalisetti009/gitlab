import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import getAiFeatureSettingsQuery from 'ee/pages/admin/ai/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import AiFeatureSettingsTable from 'ee/pages/admin/ai/feature_settings/components/feature_settings_table.vue';
import AiFeatureSettingsPage from 'ee/pages/admin/ai/custom_models/ai_feature_settings_page.vue';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import { mockAiFeatureSettings } from '../feature_settings/mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('AiFeatureSettingsPage', () => {
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

    wrapper = shallowMount(AiFeatureSettingsPage, {
      apolloProvider: mockApollo,
    });
  };

  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findAiFeatureSettingsTable = () => wrapper.findComponent(AiFeatureSettingsTable);

  describe('when feature settings data is loading', () => {
    it('renders skeleton loader', () => {
      createComponent();

      expect(findLoader().exists()).toBe(true);
    });
  });

  describe('when the API query is successful', () => {
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
    describe('due to of a general error', () => {
      it('displays an error message', async () => {
        createComponent({
          apolloHandlers: [[getAiFeatureSettingsQuery, jest.fn().mockRejectedValue('ERROR')]],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the AI feature settings. Please try again.',
          }),
        );
      });
    });

    describe('due to a business logic error', () => {
      const getAiFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiFeatureSettings: {
            errors: ['An error occured'],
          },
        },
      });

      it('displays an error message', async () => {
        createComponent({
          apolloHandlers: [[getAiFeatureSettingsQuery, getAiFeatureSettingsErrorHandler]],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the AI feature settings. Please try again.',
          }),
        );
      });
    });
  });
});
