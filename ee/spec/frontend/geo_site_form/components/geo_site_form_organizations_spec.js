import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import organizationsGraphQlResponse from 'test_fixtures/graphql/organizations/organizations.query.graphql.json';
import organizationsQuery from '~/organizations/shared/graphql/queries/organizations.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import GeoSiteFormOrganizations from 'ee/geo_site_form/components/geo_site_form_organizations.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { SELECTIVE_SYNC_ORGANIZATIONS } from 'ee/geo_site_form/constants';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('GeoSiteFormOrganizations', () => {
  let wrapper;
  let mockApollo;

  const {
    data: { organizations },
  } = organizationsGraphQlResponse;

  const defaultProps = {
    selectedOrganizationIds: [getIdFromGraphQLId(organizations.nodes[0].id)],
  };

  const createMockResponse = ({ nodes, pageInfo = {} } = {}) => {
    return {
      data: {
        organizations: {
          nodes: nodes ?? organizations.nodes,
          pageInfo: { ...organizations.pageInfo, ...pageInfo },
        },
      },
    };
  };

  const successHandler = jest.fn().mockResolvedValue(createMockResponse());

  const createComponent = ({ handler = successHandler, props = {} } = {}) => {
    mockApollo = createMockApollo([[organizationsQuery, handler]]);

    wrapper = shallowMount(GeoSiteFormOrganizations, {
      apolloProvider: mockApollo,
      propsData: { ...defaultProps, ...props },
    });
  };

  const findGlCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  it('renders listbox with correct props', () => {
    createComponent();

    expect(findGlCollapsibleListbox().props()).toMatchObject({
      items: [],
      selected: defaultProps.selectedOrganizationIds,
      searching: true,
      noResultsText: 'Nothing found…',
      toggleText: '1 organization selected',
      multiple: true,
      infiniteScroll: true,
    });
  });

  describe('when organizations API call is successful', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('loads organizations as listbox option', () => {
      const expectedItems = organizations.nodes.map((node) => ({
        text: node.name,
        value: getIdFromGraphQLId(node.id),
      }));

      expect(findGlCollapsibleListbox().props('items')).toEqual(expectedItems);
      expect(findGlCollapsibleListbox().props('searching')).toBe(false);
    });
  });

  describe('when organizations API call fails', () => {
    const error = new Error();

    beforeEach(async () => {
      createComponent({ handler: jest.fn().mockRejectedValue(error) });
      await waitForPromises();
    });

    it('does not update listbox option', () => {
      expect(findGlCollapsibleListbox().props('items')).toEqual([]);
      expect(findGlCollapsibleListbox().props('searching')).toBe(false);
    });

    it('renders error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: "There was an error fetching the Site's Organizations",
        error,
        captureError: true,
      });
    });
  });

  describe.each`
    selectedItems | dropdownTitle
    ${0}          | ${'Select organizations to replicate'}
    ${1}          | ${'1 organization selected'}
    ${3}          | ${'3 organizations selected'}
  `('when $selectedItems organizations are selected', ({ selectedItems, dropdownTitle }) => {
    beforeEach(() => {
      const selectedOrganizationIds = organizations.nodes
        .slice(0, selectedItems)
        .map((node) => getIdFromGraphQLId(node.id));

      createComponent({ props: { selectedOrganizationIds } });
    });

    it(`displays "${dropdownTitle}"`, () => {
      expect(findGlCollapsibleListbox().props('toggleText')).toBe(dropdownTitle);
    });
  });

  describe('when listbox emits `select` event', () => {
    beforeEach(() => {
      createComponent();

      findGlCollapsibleListbox().vm.$emit('select', 1);
    });

    it('emits `updateSyncOptions`', () => {
      expect(wrapper.emitted('updateSyncOptions')).toEqual([
        [{ key: SELECTIVE_SYNC_ORGANIZATIONS, value: 1 }],
      ]);
    });
  });

  describe('when listbox emits `bottom-reached` event', () => {
    const firstPageItemCount = organizations.nodes.length;

    describe('when has no next page', () => {
      beforeEach(async () => {
        const response = createMockResponse({ pageInfo: { hasNextPage: false } });
        const handler = jest.fn().mockResolvedValue(response);

        createComponent({ handler });
        await waitForPromises();

        findGlCollapsibleListbox().vm.$emit('bottom-reached');
        await waitForPromises();
      });

      it('does not load more items', () => {
        expect(findGlCollapsibleListbox().props('items')).toHaveLength(firstPageItemCount);
      });
    });

    describe('when has next page', () => {
      beforeEach(async () => {
        const response = createMockResponse({ pageInfo: { hasNextPage: true } });
        const handler = jest.fn().mockResolvedValue(response);

        createComponent({ handler });
        await waitForPromises();

        findGlCollapsibleListbox().vm.$emit('bottom-reached');
        await waitForPromises();
      });

      it('load more items', () => {
        expect(findGlCollapsibleListbox().props('items').length).toBeGreaterThan(
          firstPageItemCount,
        );
      });
    });
  });
});
