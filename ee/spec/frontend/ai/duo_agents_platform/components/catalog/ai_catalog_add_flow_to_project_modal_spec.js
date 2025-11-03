import { GlForm, GlFormCheckbox, GlFormCheckboxGroup, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AiCatalogAddFlowToProjectModal from 'ee/ai/duo_agents_platform/components/catalog/ai_catalog_add_flow_to_project_modal.vue';
import AiCatalogGroupFlowDropdown from 'ee/ai/duo_agents_platform/components/catalog/ai_catalog_group_flow_dropdown.vue';
import { mockFlowItemConsumer } from 'ee_jest/ai/catalog/mock_data';
import { stubComponent } from 'helpers/stub_component';

describe('AiCatalogAddFlowToProjectModal', () => {
  let wrapper;

  const modalStub = { hide: jest.fn() };
  const GlModalStub = stubComponent(GlModal, { methods: modalStub });

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findGroupFlowDropdown = () => wrapper.findComponent(AiCatalogGroupFlowDropdown);
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
      stubs: {
        GlModal: GlModalStub,
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

    it('renders form', () => {
      expect(findForm().exists()).toBe(true);
    });

    it('renders group flow dropdown', () => {
      expect(findGroupFlowDropdown().exists()).toBe(true);
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
    const mockInput = {
      preventDefault: jest.fn(),
    };

    beforeEach(() => {
      findGroupFlowDropdown().vm.$emit('input', mockFlowItemConsumer);
      findFormCheckboxGroup().vm.$emit('input', ['mention']);

      findForm().vm.$emit('submit', mockInput);
    });

    it('hides the modal', () => {
      expect(modalStub.hide).toHaveBeenCalled();
    });

    it('emits submit event when form is submitted', () => {
      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toEqual({
        itemId: mockFlowItemConsumer.item.id,
        flowName: mockFlowItemConsumer.item.name,
        parentItemConsumerId: mockFlowItemConsumer.id,
        triggerTypes: ['mention'],
      });
    });
  });
});
