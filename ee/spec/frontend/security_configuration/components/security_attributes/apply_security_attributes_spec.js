import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount, mount } from '@vue/test-utils';
import { GlTableLite, GlButton } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import ApplySecurityAttributes from 'ee/security_configuration/security_attributes/components/apply_security_attributes.vue';
import ProjectAttributesDrawer from 'ee/security_configuration/security_attributes/components/project_attributes_drawer.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getSecurityAttributeCategoriesQuery from 'ee/security_configuration/graphql/client/security_attribute_categories.query.graphql';
import getProjectSecurityAttributesQuery from 'ee/security_configuration/graphql/client/project_security_attributes.query.graphql';
import getSecurityAttributesByCategoryQuery from 'ee/security_configuration/graphql/client/security_attributes_by_category.query.graphql';
import { mockSecurityAttributeCategories } from 'ee/security_configuration/security_attributes/graphql/resolvers';
import { expectedAttributes } from './mock_data';

Vue.use(VueApollo);

describe('ApplySecurityAttributes', () => {
  let wrapper;

  const findTableRowAt = (i) =>
    wrapper.findComponent(GlTableLite).find('tbody').findAll('tr').at(i);
  const findTableRowTextAt = (i) => findTableRowAt(i).text();
  const findTableRowButtonTextAt = (i) => findTableRowAt(i).findComponent(GlButton).text();
  const findDrawer = () => wrapper.findComponent(ProjectAttributesDrawer);

  const groupCategoriesQueryHandler = jest.fn().mockResolvedValue({
    data: {
      group: {
        id: 'gid://gitlab/Group/group',
        securityAttributeCategories: {
          nodes: mockSecurityAttributeCategories,
        },
      },
    },
  });
  const groupAttributesQueryHandler = jest.fn().mockResolvedValue({
    data: {
      group: {
        id: 'gid://gitlab/Group/group',
        securityAttributes: {
          nodes: expectedAttributes,
        },
      },
    },
  });
  const projectQueryHandler = jest.fn().mockResolvedValue({
    data: {
      project: {
        id: 'gid://gitlab/Project/project',
        securityAttributes: {
          nodes: expectedAttributes,
        },
      },
    },
  });

  const createComponent = (
    mountFn = shallowMount,
    requestHandlers = [
      [getProjectSecurityAttributesQuery, projectQueryHandler],
      [getSecurityAttributeCategoriesQuery, groupCategoriesQueryHandler],
      [getSecurityAttributesByCategoryQuery, groupAttributesQueryHandler],
    ],
  ) => {
    const apolloProvider = createMockApollo(requestHandlers);
    wrapper = mountFn(ApplySecurityAttributes, {
      provide: {
        groupFullPath: 'path/to/group',
        projectFullPath: 'path/to/project',
        canManageAttributes: false,
        groupManageAttributesPath: 'path/to/group/-/security/configuration',
      },
      apolloProvider,
      stubs: {
        GlTableLite,
      },
    });
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  beforeEach(() => {
    createComponent();
  });

  it('tracks a page view', () => {
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    expect(trackEventSpy).toHaveBeenCalledWith('view_project_security_attributes', {}, undefined);
  });

  it('renders page heading, tab, and description', () => {
    expect(wrapper.text()).toContain(
      'Security attributes help classify and organize your projects',
    );
  });

  it('renders the list of attributes with category, name, description, and remove button', async () => {
    createComponent(mount);

    await waitForPromises();

    expectedAttributes.forEach((expectedAttribute, i) => {
      expect(findTableRowTextAt(i)).toContain(expectedAttribute.category.name);
      expect(findTableRowTextAt(i)).toContain(expectedAttribute.name);
      expect(findTableRowTextAt(i)).toContain(expectedAttribute.description);
      expect(findTableRowButtonTextAt(i)).toBe('Remove attribute');
    });
  });

  it('opens and closes the editing drawer', async () => {
    createComponent(mount);
    await waitForPromises();

    expect(findDrawer().props('open')).toBe(false);

    wrapper.findComponent(GlButton).trigger('click');
    await nextTick();

    expect(findDrawer().props('open')).toBe(true);

    findDrawer().vm.$emit('cancel');
    await nextTick();

    expect(findDrawer().props('open')).toBe(false);
  });
});
