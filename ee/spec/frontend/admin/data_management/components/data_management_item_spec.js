import { shallowMount } from '@vue/test-utils';
import models from 'test_fixtures/api/admin/data_management/snippet_repository.json';
import DataManagementItem from 'ee/admin/data_management/components/data_management_item.vue';
import GeoListItem from 'ee/geo_shared/list/components/geo_list_item.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

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
