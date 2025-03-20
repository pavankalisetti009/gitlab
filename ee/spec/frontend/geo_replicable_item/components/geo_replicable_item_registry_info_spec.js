import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoReplicableItemRegistryInfo from 'ee/geo_replicable_item/components/geo_replicable_item_registry_info.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import { MOCK_REPLICABLE_CLASS, MOCK_REPLICABLE_WITH_VERIFICATION } from '../mock_data';

describe('GeoReplicableItemReplicationInfo', () => {
  let wrapper;

  const defaultProps = {
    replicableItem: MOCK_REPLICABLE_WITH_VERIFICATION,
    registryId: `${MOCK_REPLICABLE_CLASS.graphqlRegistryClass}/${MOCK_REPLICABLE_WITH_VERIFICATION.replicableItemId}`,
  };

  const createComponent = ({ props = {} } = {}) => {
    const propsData = {
      ...defaultProps,
      ...props,
    };

    wrapper = shallowMountExtended(GeoReplicableItemRegistryInfo, {
      propsData,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findCopyableRegistryInformation = () =>
    wrapper.findAllByTestId('copyable-registry-information');
  const findRegistryInformationCreatedAt = () => wrapper.findComponent(TimeAgo);

  describe('registry information', () => {
    beforeEach(() => {
      createComponent();
    });

    it.each`
      index | title              | value
      ${0}  | ${'Registry ID'}   | ${defaultProps.registryId}
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
});
