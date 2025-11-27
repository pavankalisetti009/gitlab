import { GlCollapsibleListbox } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { getMavenUpstreamRegistriesList } from 'ee/api/virtual_registries_api';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UpstreamSelector from 'ee/packages_and_registries/virtual_registries/components/maven/registries/show/upstream_selector.vue';
import {
  upstreamsResponse,
  multipleUpstreamsResponse,
} from 'ee_jest/packages_and_registries/virtual_registries/mock_data';

jest.mock('ee/api/virtual_registries_api', () => ({
  getMavenUpstreamRegistriesList: jest.fn(),
}));

describe('UpstreamSelector', () => {
  let wrapper;

  const defaultProps = {
    linkedUpstreams: [],
    upstreamsCount: 1,
    initialUpstreams: upstreamsResponse.data,
  };

  const createComponent = ({ props = defaultProps } = {}) => {
    wrapper = shallowMountExtended(UpstreamSelector, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        groupPath: 'full-path',
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);

  it('renders GlCollapsible listbox with right props', () => {
    createComponent();

    expect(findDropdown().props()).toMatchObject({
      block: true,
      toggleId: 'upstream-select',
      toggleText: '',
      infiniteScroll: true,
      searchable: true,
      noResultsText: 'No matching results',
      infiniteScrollLoading: false,
    });

    expect(findDropdown().props('items')).toStrictEqual([
      {
        value: 3,
        text: 'test',
        secondaryText: 'test description',
      },
    ]);
  });

  it('does not call fetchUpstreams initially', () => {
    createComponent();
    expect(getMavenUpstreamRegistriesList).not.toHaveBeenCalled();
  });

  describe('when listbox emits `bottom-reached` event', () => {
    describe('when upstream count is less than total count', () => {
      beforeEach(() => {
        getMavenUpstreamRegistriesList.mockResolvedValue(upstreamsResponse);
        createComponent({
          props: {
            upstreamsCount: 2,
            initialUpstreams: [multipleUpstreamsResponse.data[1]],
          },
        });
        findDropdown().vm.$emit('bottom-reached');
      });

      it('calls getMavenUpstreamRegistriesList API', () => {
        expect(getMavenUpstreamRegistriesList).toHaveBeenCalledWith({
          id: 'full-path',
          params: {
            upstream_name: '',
            page: 2,
            per_page: 20,
          },
        });
      });

      it('when API is successful, updates dropdown items', () => {
        expect(findDropdown().props('items')).toStrictEqual([
          {
            secondaryText: 'Maven Central',
            text: 'Maven upstream',
            value: 2,
          },
          {
            value: 3,
            text: 'test',
            secondaryText: 'test description',
          },
        ]);
      });
    });

    it('does not call getMavenUpstreamRegistriesList API when upstream count is equal to total count', async () => {
      createComponent();
      await findDropdown().vm.$emit('bottom-reached');

      expect(getMavenUpstreamRegistriesList).not.toHaveBeenCalled();
    });

    it('does not call getMavenUpstreamRegistriesList API when request is in progress', async () => {
      createComponent({
        props: {
          upstreamsCount: 2,
          initialUpstreams: [multipleUpstreamsResponse.data[1]],
        },
      });
      await findDropdown().vm.$emit('bottom-reached');

      expect(findDropdown().props('infiniteScrollLoading')).toBe(true);

      await findDropdown().vm.$emit('bottom-reached');

      expect(getMavenUpstreamRegistriesList).toHaveBeenCalledTimes(1);

      await waitForPromises();

      expect(findDropdown().props('infiniteScrollLoading')).toBe(false);
    });
  });

  describe('when listbox emits `search` event', () => {
    it('calls getMavenUpstreamRegistriesList API with search term', async () => {
      getMavenUpstreamRegistriesList.mockResolvedValue(multipleUpstreamsResponse);
      createComponent();
      await findDropdown().vm.$emit('search', 'Maven');

      expect(getMavenUpstreamRegistriesList).toHaveBeenCalledWith({
        id: 'full-path',
        params: {
          upstream_name: 'Maven',
          page: 1,
          per_page: 20,
        },
      });
    });
  });

  describe('when listbox emits `select` event', () => {
    beforeEach(() => {
      createComponent();
      findDropdown().vm.$emit('select', 3);
    });

    it('emits select event with the selected upstream ID', () => {
      expect(wrapper.emitted('select')).toEqual([[3]]);
    });

    it('sets listbox toggleText prop', () => {
      expect(findDropdown().props('toggleText')).toBe('test');
    });
  });
});
