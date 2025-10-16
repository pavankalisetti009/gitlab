import { shallowMount } from '@vue/test-utils';
import AdminDataManagementApp from 'ee/admin/data_management/components/app.vue';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import { MOCK_MODEL_CLASS } from 'ee_jest/admin/data_management/mock_data';
import { DEFAULT_SORT, GEO_TROUBLESHOOTING_LINK } from 'ee/admin/data_management/constants';
import { visitUrl } from '~/lib/utils/url_utility';
import { TEST_HOST } from 'spec/test_constants';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

describe('AdminDataManagementApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(AdminDataManagementApp, {
      propsData: {
        modelClass: MOCK_MODEL_CLASS,
      },
    });
  };

  const findGeoListTopBar = () => wrapper.findComponent(GeoListTopBar);
  const findGeoList = () => wrapper.findComponent(GeoList);

  beforeEach(() => {
    createComponent();
  });

  it('renders GeoListTopBar', () => {
    expect(findGeoListTopBar().props()).toMatchObject({
      pageHeadingTitle: 'Data management',
      pageHeadingDescription: 'Review stored data and data health within your instance.',
      filteredSearchOptionLabel: 'Search by ID',
      activeListboxItem: MOCK_MODEL_CLASS.name,
      activeSort: DEFAULT_SORT,
    });
  });

  it('renders GeoList', () => {
    expect(findGeoList().props()).toMatchObject({
      isLoading: false,
      hasItems: false,
      emptyState: {
        title: `No ${MOCK_MODEL_CLASS.titlePlural.toLowerCase()} exist`,
        description:
          'If you believe this is an error, see the %{linkStart}Geo troubleshooting%{linkEnd} documentation.',
        helpLink: GEO_TROUBLESHOOTING_LINK,
      },
    });
  });

  describe('when GeoListTopBar emits `listboxChange` event', () => {
    it('redirects to page with correct params', () => {
      findGeoListTopBar().vm.$emit('listboxChange', 'foo');

      expect(visitUrl).toHaveBeenCalledWith(`${TEST_HOST}/?model_name=foo`);
    });
  });
});
