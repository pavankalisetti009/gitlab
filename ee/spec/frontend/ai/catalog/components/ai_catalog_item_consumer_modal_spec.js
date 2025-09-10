import { nextTick } from 'vue';
import { noop } from 'lodash';
import { GlForm, GlFormGroup, GlModal, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogItemConsumerModal from 'ee/ai/catalog/components/ai_catalog_item_consumer_modal.vue';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';
import { mockAgents } from '../mock_data';

describe('AiCatalogItemConsumerModal', () => {
  let wrapper;
  const agent = mockAgents[0];

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findPrivateAlert = () => wrapper.findByTestId('private-alert');
  const findProjectDropdown = () => wrapper.findComponent(FormProjectDropdown);

  const createWrapper = ({ item = agent } = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemConsumerModal, {
      propsData: {
        item,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    createWrapper();
  });

  describe('component rendering', () => {
    it('renders modal and item name', () => {
      expect(findModal().props('title')).toBe('Add this agent to a project');
      expect(findModal().find('dt').text()).toBe('Selected agent');
      expect(findModal().find('dd').text()).toBe(agent.name);
    });

    it('renders the label description of the project field', () => {
      expect(findFormGroup().props('labelDescription')).toBe(
        'Project members will be able to run this agent.',
      );
    });

    describe('when the item is private', () => {
      beforeEach(() => {
        createWrapper({ item: { ...agent, public: false } });
      });

      it('renders private alert', () => {
        expect(findPrivateAlert().exists()).toBe(true);
      });

      it('does not render project dropdown', () => {
        expect(findProjectDropdown().exists()).toBe(false);
      });
    });

    describe('when the item is public', () => {
      it('renders project dropdown', () => {
        expect(findProjectDropdown().exists()).toBe(true);
      });

      it('renders project dropdown with preselected project', () => {
        expect(findProjectDropdown().props('value')).toBe(agent.project.id);
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
        createWrapper({ item: { ...agent, project: null } });
      });

      it('renders alert', async () => {
        findForm().vm.$emit('submit', { preventDefault: noop });
        await nextTick();

        expect(findErrorAlert().text()).toBe('Project is required.');
        expect(wrapper.emitted('submit')).toBeUndefined();
      });
    });
  });

  describe('when the modal emits the hidden event', () => {
    it('emits the hide event', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('hide')).toHaveLength(1);
    });
  });
});
