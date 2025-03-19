import { GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import GeoReplicableItemApp from 'ee/geo_replicable_item/components/app.vue';
import buildReplicableItemQuery from 'ee/geo_replicable_item/graphql/replicable_item_query_builder';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
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
  const findCopyableRegistryInformation = () =>
    wrapper.findAllByTestId('copyable-registry-information');
  const findRegistryInformationCreatedAt = () => wrapper.findComponent(TimeAgo);

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

    it.each`
      index | title              | value
      ${0}  | ${'Registry ID'}   | ${`${MOCK_REPLICABLE_CLASS.graphqlRegistryClass}/${defaultProps.replicableItemId}`}
      ${1}  | ${'GraphQL ID'}    | ${MOCK_REPLICABLE_WITH_VERIFICATION.id}
      ${2}  | ${'Replicable ID'} | ${MOCK_REPLICABLE_WITH_VERIFICATION.modelRecordId}
    `('renders $title: $value with clipboard button', ({ index, title, value }) => {
      const registryDetails = findCopyableRegistryInformation().at(index);

      expect(registryDetails.text()).toBe(`${title}: ${value}`);
      expect(registryDetails.findComponent(ClipboardButton).props('text')).toBe(String(value));
    });

    it('renders TimeAgo component for createAt', () => {
      expect(findRegistryInformationCreatedAt().props('time')).toBe(
        MOCK_REPLICABLE_WITH_VERIFICATION.createdAt,
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
