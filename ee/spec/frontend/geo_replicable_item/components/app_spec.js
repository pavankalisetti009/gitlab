import { GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import GeoReplicableItemApp from 'ee/geo_replicable_item/components/app.vue';
import GeoReplicableItemRegistryInfo from 'ee/geo_replicable_item/components/geo_replicable_item_registry_info.vue';
import buildReplicableItemQuery from 'ee/geo_replicable_item/graphql/replicable_item_query_builder';
import { createAlert } from '~/alert';
import {
  MOCK_REPLICABLE_CLASS,
  MOCK_REPLICABLE_WITH_VERIFICATION,
  MOCK_REPLICABLE_WITHOUT_VERIFICATION,
} from '../mock_data';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('GeoReplicableItemApp', () => {
  let wrapper;

  const defaultProps = {
    replicableClass: MOCK_REPLICABLE_CLASS,
    replicableItemId: '1',
  };

  const createComponent = ({ props = {}, handler } = {}) => {
    const propsData = {
      ...defaultProps,
      ...props,
    };

    const query = buildReplicableItemQuery(
      propsData.replicableClass.graphqlFieldName,
      propsData.replicableClass.verificationEnabled,
    );

    const mockReplicable = propsData.replicableClass.verificationEnabled
      ? MOCK_REPLICABLE_WITH_VERIFICATION
      : MOCK_REPLICABLE_WITHOUT_VERIFICATION;

    const apolloQueryHandler =
      handler ||
      jest.fn().mockResolvedValue({
        data: {
          geoNode: {
            [defaultProps.replicableClass.graphqlFieldName]: {
              nodes: [
                {
                  ...mockReplicable,
                },
              ],
            },
          },
        },
      });

    const apolloProvider = createMockApollo([[query, apolloQueryHandler]]);

    wrapper = shallowMountExtended(GeoReplicableItemApp, {
      propsData,
      apolloProvider,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findRegistryInfoComponent = () => wrapper.findComponent(GeoReplicableItemRegistryInfo);

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GlLoadingIcon initially', () => {
      expect(findGlLoadingIcon().exists()).toBe(true);
    });
  });

  describe('registry information', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('renders registry info component with correct props', () => {
      expect(findRegistryInfoComponent().props('replicableItem')).toStrictEqual(
        MOCK_REPLICABLE_WITH_VERIFICATION,
      );
      expect(findRegistryInfoComponent().props('registryId')).toBe(
        `${MOCK_REPLICABLE_CLASS.graphqlRegistryClass}/${defaultProps.replicableItemId}`,
      );
    });
  });

  describe('error handling', () => {
    it('displays error message when Apollo query fails', async () => {
      const errorMessage = new Error('GraphQL Error');
      const handler = jest.fn().mockRejectedValue(errorMessage);
      createComponent({ handler });

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: "There was an error fetching this replicable's details",
        captureError: true,
        error: errorMessage,
      });
    });
  });
});
