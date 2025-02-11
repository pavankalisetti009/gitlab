import { GlLoadingIcon } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import GeoReplicableItemApp from 'ee/geo_replicable_item/components/app.vue';
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
    });
  };

  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findReplicableItemDetails = () => wrapper.findByTestId('replicable-item-details');

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GlLoadingIcon initially', () => {
      expect(findGlLoadingIcon().exists()).toBe(true);
    });

    it('renders replicable item details after loading', async () => {
      await waitForPromises();

      expect(findGlLoadingIcon().exists()).toBe(false);
      expect(findReplicableItemDetails().text().replace(/\s+/g, '')).toBe(
        JSON.stringify(MOCK_REPLICABLE_WITH_VERIFICATION),
      );
    });
  });

  describe('verification details', () => {
    describe('with verification disabled', () => {
      beforeEach(async () => {
        createComponent({
          props: { replicableClass: { ...MOCK_REPLICABLE_CLASS, verificationEnabled: false } },
        });
        await waitForPromises();
      });

      it('does not render verification information', () => {
        expect(findReplicableItemDetails().text()).not.toContain('verifiedAt');
      });
    });

    describe('with verification enabled', () => {
      beforeEach(async () => {
        createComponent({
          props: { replicableClass: { ...MOCK_REPLICABLE_CLASS, verificationEnabled: true } },
        });
        await waitForPromises();
      });

      it('does render verification information', () => {
        expect(findReplicableItemDetails().text()).toContain('verifiedAt');
      });
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
