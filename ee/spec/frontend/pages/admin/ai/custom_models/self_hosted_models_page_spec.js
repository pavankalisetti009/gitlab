import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import getSelfHostedModelsQuery from 'ee/pages/admin/ai/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import SelfHostedModelsTable from 'ee/pages/admin/ai/self_hosted_models/components/self_hosted_models_table.vue';
import SelfHostedModelsPage from 'ee/pages/admin/ai/custom_models/self_hosted_models_page.vue';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import { mockSelfHostedModelsList } from '../self_hosted_models/mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('SelfHostedModelsPage', () => {
  let wrapper;

  const getSelfHostedModelsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModels: {
        nodes: mockSelfHostedModelsList,
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [[getSelfHostedModelsQuery, getSelfHostedModelsSuccessHandler]],
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = shallowMount(SelfHostedModelsPage, { apolloProvider: mockApollo });
  };

  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findSelfHostedModelsTable = () => wrapper.findComponent(SelfHostedModelsTable);

  describe('when model data is loading', () => {
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

    it('renders the self-hosted models table and passes the correct props', () => {
      expect(findSelfHostedModelsTable().props('models')).toEqual(mockSelfHostedModelsList);
      expect(findSelfHostedModelsTable().props('basePath')).toEqual(
        '/admin/ai/self_hosted_models/',
      );
    });
  });

  describe('when the API request is unsuccessful', () => {
    describe('due to of a general error', () => {
      it('displays an error message', async () => {
        createComponent({
          apolloHandlers: [[getSelfHostedModelsQuery, jest.fn().mockRejectedValue('ERROR')]],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading self-hosted models. Please try again.',
          }),
        );
      });
    });

    describe('due to a business logic error', () => {
      const getSelfHostedModelsErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiFeatureSettings: {
            errors: ['An error occured'],
          },
        },
      });

      it('displays an error message', async () => {
        createComponent({
          apolloHandlers: [[getSelfHostedModelsQuery, getSelfHostedModelsErrorHandler]],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading self-hosted models. Please try again.',
          }),
        );
      });
    });
  });
});
