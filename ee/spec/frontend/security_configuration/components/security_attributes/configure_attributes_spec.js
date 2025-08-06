import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import {
  mockSecurityAttributeCategories,
  mockSecurityAttributes,
} from 'ee/security_configuration/security_attributes/graphql/resolvers';
import ConfigureAttributes from 'ee/security_configuration/components/security_attributes/configure_attributes.vue';
import CategoryList from 'ee/security_configuration/components/security_attributes/category_list.vue';
import CategoryForm from 'ee/security_configuration/components/security_attributes/category_form.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import getSecurityAttributesQuery from 'ee/security_configuration/graphql/client/security_attributes.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

Vue.use(VueApollo);

const firstCategory = mockSecurityAttributeCategories[0];
const secondCategory = mockSecurityAttributeCategories[1];

describe('Configure attributes', () => {
  let wrapper;

  const queryHandler = jest.fn().mockResolvedValue({
    data: {
      group: {
        id: 'gid://gitlab/Group/group',
        securityAttributeCategories: { nodes: mockSecurityAttributeCategories },
        securityAttributes: { nodes: mockSecurityAttributes },
      },
    },
  });

  const createComponent = (requestHandlers = [[getSecurityAttributesQuery, queryHandler]]) => {
    const apolloProvider = createMockApollo(requestHandlers, [], {
      typePolicies: {
        Query: {
          fields: {
            group: {
              merge: true,
            },
          },
        },
      },
    });
    wrapper = shallowMount(ConfigureAttributes, {
      provide: { groupFullPath: 'path/to/group' },
      apolloProvider,
    });
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  it('tracks a page view', () => {
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    expect(trackEventSpy).toHaveBeenCalledWith('view_group_security_attributes', {}, undefined);
  });

  it('queries for the security attribute categories', () => {
    expect(queryHandler).toHaveBeenCalledWith({
      categoryId: undefined,
      fullPath: 'path/to/group',
    });
  });

  it('renders the list of categories', () => {
    expect(wrapper.findComponent(CategoryList).props()).toStrictEqual({
      securityAttributeCategories: mockSecurityAttributeCategories,
      selectedCategory: firstCategory,
    });
  });

  it('changes selected category when list emits selectCategory', async () => {
    expect(wrapper.findComponent(CategoryForm).props('category')).toStrictEqual(firstCategory);

    wrapper.findComponent(CategoryList).vm.$emit('selectCategory', secondCategory);
    await nextTick();

    expect(wrapper.findComponent(CategoryForm).props('category')).toStrictEqual(secondCategory);
  });

  it('renders the category details form', () => {
    expect(wrapper.findComponent(CategoryForm).props()).toStrictEqual({
      securityAttributes: mockSecurityAttributes,
      category: firstCategory,
    });
  });

  it('opens the drawer when form emits addAttribute', async () => {
    wrapper.vm.$refs.attributeDrawer.open = jest.fn();

    wrapper.findComponent(CategoryForm).vm.$emit('addAttribute');
    await nextTick();

    expect(wrapper.vm.$refs.attributeDrawer.open).toHaveBeenCalledWith('add', undefined);
  });

  it('opens the drawer when form emits editAttribute', async () => {
    wrapper.vm.$refs.attributeDrawer.open = jest.fn();

    wrapper.findComponent(CategoryForm).vm.$emit('editAttribute', mockSecurityAttributes[0]);
    await nextTick();

    expect(wrapper.vm.$refs.attributeDrawer.open).toHaveBeenCalledWith(
      'edit',
      expect.objectContaining({ name: 'Asset Track' }),
    );
  });
});
