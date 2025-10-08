import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlDrawer, GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import ProjectAttributesUpdateDrawer from 'ee/security_configuration/security_attributes/components/project_attributes_update_drawer.vue';
import ProjectAttributesUpdateForm from 'ee/security_configuration/security_attributes/components/project_attributes_update_form.vue';
import getSecurityCategoriesAndAttributes from 'ee/security_configuration/graphql/group_security_categories_and_attributes.query.graphql';
import ProjectSecurityAttributesUpdateMutation from 'ee/security_configuration/graphql/project_security_attributes_update.mutation.graphql';
import { mockSecurityAttributeCategories } from './mock_data';

Vue.use(VueApollo);

describe('ProjectAttributesUpdateDrawer', () => {
  let wrapper;

  const groupCategoriesQueryHandler = jest.fn().mockResolvedValue({
    data: {
      group: {
        id: 'gid://gitlab/Group/group',
        securityCategories: mockSecurityAttributeCategories,
      },
    },
  });

  const updateAttributesMock = jest.fn().mockResolvedValue({
    data: {
      securityAttributeProjectUpdate: {
        addedCount: 2,
        removedCount: 2,
        errors: [],
      },
    },
  });

  const createComponent = (mountFn = shallowMountExtended) => {
    const apolloProvider = createMockApollo([
      [getSecurityCategoriesAndAttributes, groupCategoriesQueryHandler],
      [ProjectSecurityAttributesUpdateMutation, updateAttributesMock],
    ]);

    wrapper = mountFn(ProjectAttributesUpdateDrawer, {
      propsData: {
        projectId: 'gid://gitlab/Project/1',
        selectedAttributes: [{ id: '1' }, { id: '2' }],
      },
      provide: { groupFullPath: 'path/to/group' },
      apolloProvider,
      stubs: { GlDrawer },
      mocks: { $toast: { show: jest.fn() } },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findCancelButton = () => wrapper.findByTestId('cancel-btn');
  const findSubmitButton = () => wrapper.findByTestId('submit-btn');
  const findForm = () => wrapper.findComponent(ProjectAttributesUpdateForm);
  const findSkeleton = () => wrapper.findComponent(GlSkeletonLoader);

  beforeEach(async () => {
    createComponent();
    wrapper.vm.openDrawer();
    await waitForPromises();
  });

  describe('initial render', () => {
    it('renders GlDrawer open with correct props', () => {
      expect(findDrawer().exists()).toBe(true);
      expect(findDrawer().props()).toMatchObject({
        open: true,
        zIndex: DRAWER_Z_INDEX,
      });
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
      wrapper.vm.openDrawer();
    });

    it('does not render the form while loading', () => {
      expect(findForm().exists()).toBe(false);
    });

    it('shows the skeleton loader while loading', () => {
      expect(findSkeleton().exists()).toBe(true);
    });
  });

  describe('ready state', () => {
    it('renders the form and hides the skeleton loader after loading', () => {
      expect(findForm().exists()).toBe(true);
      expect(findSkeleton().exists()).toBe(false);
    });
  });

  describe('actions', () => {
    it('calls mutation with correct payload and shows toast', async () => {
      const updatedAttributes = ['3', '4'];
      findForm().vm.$emit('update', updatedAttributes);
      await nextTick();

      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(updateAttributesMock).toHaveBeenCalledWith({
        input: {
          projectId: 'gid://gitlab/Project/1',
          addAttributeIds: ['3', '4'],
          removeAttributeIds: ['1', '2'],
        },
      });

      expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
        'Successfully added 2 and removed 2 security attributes',
      );

      expect(wrapper.emitted('saved')).toHaveLength(1);
      expect(findDrawer().props('open')).toBe(false);
    });
  });

  describe('footer', () => {
    it('renders both Save and Cancel buttons', () => {
      expect(findSubmitButton().exists()).toBe(true);
      expect(findCancelButton().exists()).toBe(true);
    });

    it('disables Save button when no changes are made', () => {
      expect(findSubmitButton().props('disabled')).toBe(true);
    });

    it('enables Save button after attributes update event from form', async () => {
      const newAttributes = ['3'];
      findForm().vm.$emit('update', newAttributes);
      await nextTick();

      expect(findSubmitButton().props('disabled')).toBe(false);
    });

    it('closes drawer when Cancel button is clicked', async () => {
      await findCancelButton().vm.$emit('click');
      expect(findDrawer().props('open')).toBe(false);
    });
  });
});
