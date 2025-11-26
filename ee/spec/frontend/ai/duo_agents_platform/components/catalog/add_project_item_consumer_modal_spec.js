import { GlForm, GlFormCheckbox, GlFormCheckboxGroup, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AddProjectItemConsumerModal from 'ee/ai/duo_agents_platform/components/catalog/add_project_item_consumer_modal.vue';
import GroupItemConsumerDropdown from 'ee/ai/duo_agents_platform/components/catalog/group_item_consumer_dropdown.vue';
import { mockFlowItemConsumer } from 'ee_jest/ai/catalog/mock_data';
import { stubComponent } from 'helpers/stub_component';

describe('AddProjectItemConsumerModal', () => {
  let wrapper;

  const modalStub = { hide: jest.fn() };
  const GlModalStub = stubComponent(GlModal, { methods: modalStub });

  const defaultProps = {
    itemTypes: ['FLOW'],
    modalId: 'add-flow-to-project-modal',
    modalTexts: {
      title: 'Enable flow from group',
      dropdownTexts: {},
    },
    showTriggers: true,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(AddProjectItemConsumerModal, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlModal: GlModalStub,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findGroupItemConsumerDropdown = () => wrapper.findComponent(GroupItemConsumerDropdown);
  const findFormCheckboxGroup = () => wrapper.findComponent(GlFormCheckboxGroup);
  const findFormCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders modal', () => {
      expect(findModal().props()).toMatchObject({
        title: 'Enable flow from group',
        actionPrimary: {
          text: 'Enable',
          attributes: {
            variant: 'confirm',
            type: 'submit',
          },
        },
        actionCancel: {
          text: 'Cancel',
        },
      });
    });

    it('renders form', () => {
      expect(findForm().exists()).toBe(true);
    });

    it('renders group item consumer dropdown', () => {
      expect(findGroupItemConsumerDropdown().exists()).toBe(true);
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

    beforeEach(async () => {
      await findGroupItemConsumerDropdown().vm.$emit('input', mockFlowItemConsumer);
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
        itemName: mockFlowItemConsumer.item.name,
        parentItemConsumerId: mockFlowItemConsumer.id,
        triggerTypes: ['mention'],
      });
    });

    it('resets form', () => {
      expect(findGroupItemConsumerDropdown().props('value')).toBeNull();
      expect(findFormCheckboxGroup().attributes('checked')).toEqual(
        'mention,assign,assign_reviewer',
      );
    });
  });

  describe('when showTriggers is false', () => {
    beforeEach(() => {
      createComponent({
        props: { showTriggers: false },
      });
    });

    it('does not render trigger checkboxes', () => {
      expect(findFormCheckboxGroup().exists()).toBe(false);
      expect(findFormCheckboxes()).toHaveLength(0);
    });

    it('does not pass triggerTypes on form submission', () => {
      findGroupItemConsumerDropdown().vm.$emit('input', mockFlowItemConsumer);

      findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toEqual({
        itemId: mockFlowItemConsumer.item.id,
        itemName: mockFlowItemConsumer.item.name,
        parentItemConsumerId: mockFlowItemConsumer.id,
      });
    });
  });
});
