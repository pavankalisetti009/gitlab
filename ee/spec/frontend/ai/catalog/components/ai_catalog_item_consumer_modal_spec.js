import { nextTick } from 'vue';
import { noop } from 'lodash';
import { GlForm, GlFormGroup, GlFormRadioGroup, GlModal, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import AiCatalogItemConsumerModal from 'ee/ai/catalog/components/ai_catalog_item_consumer_modal.vue';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';
import FormGroupDropdown from 'ee/ai/catalog/components/form_group_dropdown.vue';
import { mockFlow, mockProjectWithGroup } from '../mock_data';

describe('AiCatalogItemConsumerModal', () => {
  let wrapper;

  const defaultProps = {
    item: mockFlow,
    showAddToGroup: false,
  };
  const GlFormGroupStub = stubComponent(GlFormGroup, {
    props: ['state', 'labelDescription'],
  });

  const createWrapper = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemConsumerModal, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
        GlFormGroup: GlFormGroupStub,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormGroups = () => wrapper.findAllComponents(GlFormGroup);
  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findPrivateAlert = () => wrapper.findByTestId('private-alert');
  const findProjectDropdown = () => wrapper.findComponent(FormProjectDropdown);
  const findGroupDropdown = () => wrapper.findComponent(FormGroupDropdown);
  const findProjectName = () => wrapper.findByTestId('project-name');
  const findGroupName = () => wrapper.findByTestId('group-name');

  beforeEach(() => {
    createWrapper();
  });

  describe('component rendering', () => {
    it('renders modal and item name', () => {
      expect(findModal().props('title')).toBe('Enable flow in a project');
      expect(findModal().find('dt').text()).toBe('Selected flow');
      expect(findModal().find('dd').text()).toBe(mockFlow.name);
    });

    it('does not render group/project radio group', () => {
      expect(findFormRadioGroup().exists()).toBe(false);
    });

    it('renders the label description of the project field', () => {
      expect(findFormGroup().props('labelDescription')).toBe(
        'Project members will be able to use this flow.',
      );
    });

    describe('when the item is private', () => {
      beforeEach(() => {
        createWrapper({ props: { item: { ...mockFlow, public: false } } });
      });

      it('renders private alert', () => {
        expect(findPrivateAlert().exists()).toBe(true);
      });

      it('does not render project dropdown', () => {
        expect(findProjectDropdown().exists()).toBe(false);
      });
    });

    describe('when item is private but has missing project ID', () => {
      beforeEach(() => {
        createWrapper({
          props: {
            item: {
              ...mockFlow,
              public: false,
              project: { id: undefined, nameWithNamespace: 'projectNamespace' },
            },
          },
        });
      });

      it('does not render error alert due to missing project', () => {
        expect(findErrorAlert().exists()).toBe(false);
      });

      it('does not submit when missing project id', () => {
        findForm().vm.$emit('submit', { preventDefault: noop });

        expect(wrapper.emitted('submit')).toBeUndefined();
      });
    });

    describe('when the item is public', () => {
      it('renders project dropdown without a selected project', () => {
        expect(findProjectDropdown().props('value')).toBe(null);
      });

      it('does not render the error validation initially', () => {
        expect(findFormGroup().props('state')).toBe(true);
      });

      it('renders alert when there was a problem fetching the projects', async () => {
        const error = 'Failed to load projects.';

        await findProjectDropdown().vm.$emit('error', error);

        expect(findErrorAlert().text()).toBe(error);
      });

      it('does not render private alert', () => {
        expect(findPrivateAlert().exists()).toBe(false);
      });
    });
  });

  describe('when submitting the form', () => {
    it('emits the submit event', async () => {
      const projectId = 'gid://gitlab/Project/1000000';
      await findProjectDropdown().vm.$emit('input', projectId);
      findForm().vm.$emit('submit', { preventDefault: noop });

      expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
        projectId,
      });
    });

    describe('when there is no project selected', () => {
      beforeEach(() => {
        createWrapper({
          props: {
            item: { ...mockFlow, project: null },
          },
        });
      });

      it('renders alert', async () => {
        findForm().vm.$emit('submit', { preventDefault: noop });
        await nextTick();

        expect(wrapper.emitted('submit')).toBeUndefined();
        expect(findFormGroup().props('state')).toBe(false);
      });
    });
  });

  describe('when the modal emits the hidden event', () => {
    it('emits the hide event', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('hide')).toHaveLength(1);
    });
  });

  describe('when showAddToGroup is true', () => {
    beforeEach(() => {
      createWrapper({ props: { showAddToGroup: true } });
    });

    it('renders modal title for group', () => {
      expect(findModal().props('title')).toBe('Enable flow in a group');
    });

    it('renders group/project radio group', () => {
      expect(findFormRadioGroup().props('options')).toEqual([
        { value: 'group', text: 'Group' },
        { value: 'project', text: 'Project' },
      ]);
    });

    describe('when item is public', () => {
      it('renders group label description', () => {
        const groupFormGroup = findFormGroups().at(1); // Second form group (after radio group)
        expect(groupFormGroup.props('labelDescription')).toBe(
          'Allows flow to be enabled in projects.',
        );
      });

      it('renders group dropdown by default', () => {
        expect(findGroupDropdown().exists()).toBe(true);
        expect(findProjectDropdown().exists()).toBe(false);
      });

      describe('when switching target type to project', () => {
        beforeEach(async () => {
          await findFormRadioGroup().vm.$emit('input', 'project');
        });

        it('renders project dropdown instead of group dropdown', () => {
          expect(findProjectDropdown().exists()).toBe(true);
          expect(findGroupDropdown().exists()).toBe(false);
        });

        it('updates modal title for project', () => {
          expect(findModal().props('title')).toBe('Enable flow in a project');
        });
      });

      it('renders alert when there was a problem fetching groups', async () => {
        const error = 'Failed to load groups.';

        await findGroupDropdown().vm.$emit('error', error);

        expect(findErrorAlert().text()).toBe(error);
      });

      describe('form submission with group target', () => {
        it('emits submit event with groupId', async () => {
          const groupId = 'gid://gitlab/Group/2';
          await findGroupDropdown().vm.$emit('input', groupId);
          findForm().vm.$emit('submit', { preventDefault: noop });

          expect(wrapper.emitted('submit')[0][0]).toStrictEqual({
            groupId,
          });
        });

        describe('when no group is selected', () => {
          it('does not submit and shows validation error', async () => {
            findForm().vm.$emit('submit', { preventDefault: noop });
            await nextTick();

            expect(wrapper.emitted('submit')).toBeUndefined();
            const groupFormGroup = findFormGroups().at(1);
            expect(groupFormGroup.props('state')).toBe(false);
          });
        });
      });
    });

    describe('when item is private', () => {
      beforeEach(() => {
        createWrapper({
          props: {
            item: { ...mockFlow, public: false, project: mockProjectWithGroup },
            showAddToGroup: true,
          },
        });
      });

      it('renders group name instead of dropdown by default', () => {
        expect(findGroupName().text()).toBe(mockProjectWithGroup.rootGroup.fullName);
        expect(findGroupDropdown().exists()).toBe(false);
      });

      it('renders private alert', () => {
        expect(findPrivateAlert().exists()).toBe(true);
      });

      describe('when switching to project target type', () => {
        beforeEach(async () => {
          await findFormRadioGroup().vm.$emit('input', 'project');
        });

        it('renders project name instead of dropdown', () => {
          expect(findProjectName().text()).toBe(mockProjectWithGroup.nameWithNamespace);
          expect(findProjectDropdown().exists()).toBe(false);
        });
      });
    });
  });
});
