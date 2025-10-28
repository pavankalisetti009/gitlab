import { GlForm, GlFormCheckbox, GlFormCheckboxGroup, GlFormInput, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AiCatalogAddFlowToProjectModal from 'ee/ai/duo_agents_platform/components/catalog/ai_catalog_add_flow_to_project_modal.vue';

describe('AiCatalogAddFlowToProjectModal', () => {
  let wrapper;

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findFormInput = () => wrapper.findComponent(GlFormInput);
  const findFormCheckboxGroup = () => wrapper.findComponent(GlFormCheckboxGroup);
  const findFormCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);

  const createComponent = () => {
    wrapper = shallowMount(AiCatalogAddFlowToProjectModal, {
      provide: {
        flowTriggersEventTypeOptions: [
          { text: 'Mention', value: 'mention' },
          { text: 'Assign', value: 'assign' },
          { text: 'Assign reviewer', value: 'assign_reviewer' },
        ],
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders modal', () => {
      expect(findModal().props()).toMatchObject({
        title: 'Enable flow in project',
        actionPrimary: {
          text: 'Enable',
          attributes: {
            variant: 'confirm',
            type: 'submit',
          },
        },
        actionSecondary: {
          text: 'Cancel',
        },
      });
    });

    it('renders form with flow input field', () => {
      expect(findForm().exists()).toBe(true);
      expect(findFormInput().exists()).toBe(true);
    });

    it('renders pre-selected trigger type checkboxes', () => {
      expect(findFormCheckboxGroup().attributes('checked')).toEqual(
        'mention,assign,assign_reviewer',
      );

      const checkboxes = findFormCheckboxes();
      expect(checkboxes).toHaveLength(3);
      expect(checkboxes.at(0).props('value')).toBe('mention');
      expect(checkboxes.at(1).props('value')).toBe('assign');
      expect(checkboxes.at(2).props('value')).toBe('assign_reviewer');
    });
  });

  describe('form submission', () => {
    it('emits submit event when form is submitted', () => {
      const mockInput = {
        flow: 'gid://gitlab/Ai::Catalog::Item/4',
        triggers: ['mention'],
        preventDefault: jest.fn(),
      };

      findForm().vm.$emit('submit', mockInput);

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toEqual(mockInput);
    });
  });
});
