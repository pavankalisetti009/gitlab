import { shallowMount } from '@vue/test-utils';
import models from 'test_fixtures/api/admin/data_management/snippet_repository.json';
import DataManagementItem from 'ee/admin/data_management/components/data_management_item.vue';
import GeoListItem from 'ee/geo_shared/list/components/geo_list_item.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { VERIFICATION_STATUS_LABELS, VERIFICATION_STATUS_STATES } from 'ee/geo_shared/constants';

describe('DataManagementItem', () => {
  let wrapper;

  const [model] = convertObjectPropsToCamelCase(models, { deep: true });

  const createComponent = (props = {}) => {
    wrapper = shallowMount(DataManagementItem, {
      propsData: {
        item: model,
        ...props,
      },
    });
  };

  const findGeoListItem = () => wrapper.findComponent(GeoListItem);

  it('renders GeoListItem with correct props', () => {
    createComponent();

    expect(findGeoListItem().props()).toMatchObject({
      name: `${model.modelClass}/${model.recordIdentifier}`,
      timeAgoArray: [
        {
          label: 'Created',
          dateString: model.createdAt,
          defaultText: 'Unknown',
        },
        {
          label: 'Last checksum',
          dateString: model.checksumInformation.lastChecksum,
          defaultText: 'Unknown',
        },
      ],
    });
  });

  describe.each`
    checksumState  | expectedStatus                          | expectedLabel
    ${'pending'}   | ${VERIFICATION_STATUS_STATES.PENDING}   | ${VERIFICATION_STATUS_LABELS.PENDING}
    ${'started'}   | ${VERIFICATION_STATUS_STATES.STARTED}   | ${VERIFICATION_STATUS_LABELS.STARTED}
    ${'succeeded'} | ${VERIFICATION_STATUS_STATES.SUCCEEDED} | ${VERIFICATION_STATUS_LABELS.SUCCEEDED}
    ${'failed'}    | ${VERIFICATION_STATUS_STATES.FAILED}    | ${VERIFICATION_STATUS_LABELS.FAILED}
    ${'disabled'}  | ${VERIFICATION_STATUS_STATES.DISABLED}  | ${VERIFICATION_STATUS_LABELS.DISABLED}
    ${undefined}   | ${VERIFICATION_STATUS_STATES.UNKNOWN}   | ${VERIFICATION_STATUS_LABELS.UNKNOWN}
  `('when checkSum state is $checksumState', ({ checksumState, expectedStatus, expectedLabel }) => {
    it('passes correct status props to GeoListItem', () => {
      createComponent({
        item: {
          ...model,
          checksumInformation: { ...model.checksumInformation, checksumState },
        },
      });

      expect(findGeoListItem().props('statusArray')).toEqual([
        {
          tooltip: `Checksum: ${expectedStatus.title}`,
          icon: expectedStatus.icon,
          variant: expectedStatus.variant,
          label: expectedLabel,
        },
      ]);
    });
  });

  describe('when fileSize is provided', () => {
    it('renders size', () => {
      createComponent({ item: { ...model, fileSize: 1024 } });

      expect(findGeoListItem().text()).toContain('Storage: 1.00 KiB');
    });
  });

  describe('when fileSize is 0', () => {
    it('renders size"', () => {
      createComponent({ item: { ...model, fileSize: 0 } });

      expect(findGeoListItem().text()).toContain('Storage: 0 B');
    });
  });

  describe('when fileSize is not provided', () => {
    it('renders size as "Unknown"', () => {
      createComponent({ item: { ...model, fileSize: null } });

      expect(findGeoListItem().text()).toContain('Storage: Unknown');
    });
  });
});
