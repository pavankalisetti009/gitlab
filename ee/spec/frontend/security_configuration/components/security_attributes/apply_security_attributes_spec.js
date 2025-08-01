import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount, mount } from '@vue/test-utils';
import { GlTableLite, GlButton } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import ApplySecurityAttributes from 'ee/security_configuration/security_attributes/components/apply_security_attributes.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getProjectSecurityAttributesQuery from 'ee/security_configuration/graphql/client/project_security_attributes.query.graphql';
import { expectedAttributes } from './mock_data';

Vue.use(VueApollo);

describe('ApplySecurityAttributes', () => {
  let wrapper;

  const findTableRowAt = (i) =>
    wrapper.findComponent(GlTableLite).find('tbody').findAll('tr').at(i);
  const findTableRowTextAt = (i) => findTableRowAt(i).text();
  const findTableRowButtonTextAt = (i) => findTableRowAt(i).findComponent(GlButton).text();

  const queryHandler = jest.fn().mockResolvedValue({
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
    requestHandlers = [[getProjectSecurityAttributesQuery, queryHandler]],
  ) => {
    const apolloProvider = createMockApollo(requestHandlers);
    wrapper = mountFn(ApplySecurityAttributes, {
      provide: { projectFullPath: 'path/to/project' },
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
});
