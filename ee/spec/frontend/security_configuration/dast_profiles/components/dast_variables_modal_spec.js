import {
  GlModal,
  GlCollapsibleListbox,
  GlFormInput,
  GlFormGroup,
  GlFormRadioGroup,
  GlFormRadio,
  GlFormTextarea,
  GlSprintf,
  GlLink,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import DastVariablesModal from 'ee/security_configuration/dast_profiles/components/dast_variables_modal.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('DastVariablesModal', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DastVariablesModal, {
      propsData: props,
      stubs: {
        GlFormGroup,
        GlSprintf,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findVariableSelector = () => wrapper.findComponent(GlCollapsibleListbox);
  const findValueInput = () => wrapper.findComponent(GlFormInput);
  const findAllFormsGroups = () => wrapper.findAllComponents(GlFormGroup);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findAllFormRadio = () => wrapper.findAllComponents(GlFormRadio);
  const findFormTextArea = () => wrapper.findComponent(GlFormTextarea);
  const findLink = () => wrapper.findComponent(GlLink);
  const findLabelDescription = () => wrapper.findByTestId('label-description');

  beforeEach(() => {
    createComponent();
  });

  it('renders the modal', () => {
    expect(findModal().exists()).toBe(true);
  });

  it('renders all necessary components', () => {
    expect(findVariableSelector().exists()).toBe(true);
    expect(findValueInput().exists()).toBe(false);
  });

  it('should display only one form-group when the modal is open', () => {
    expect(findAllFormsGroups().length).toBe(1);
  });

  it('emits addVariable event when modal is submitted with valid data', async () => {
    await findVariableSelector().vm.$emit('select', 'DAST_ACTIVE_SCAN_TIMEOUT');
    findValueInput().vm.$emit('input', '120');
    await findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    expect(wrapper.emitted('addVariable')).toHaveLength(1);
    expect(wrapper.emitted('addVariable')).toEqual([
      [
        {
          variable: 'DAST_ACTIVE_SCAN_TIMEOUT',
          value: '120',
        },
      ],
    ]);
  });

  it('does not emit addVariable event when modal is submitted with invalid `variable` data', async () => {
    const preventDefault = jest.fn();
    await findModal().vm.$emit('primary', { preventDefault });
    expect(preventDefault).toHaveBeenCalled();
    expect(wrapper.emitted('addVariable')).toBeUndefined();
  });

  it('does not emit addVariable event when modal is submitted with invalid `value` data', async () => {
    const preventDefault = jest.fn();
    await findVariableSelector().vm.$emit('select', 'DAST_ACTIVE_SCAN_TIMEOUT');
    await findModal().vm.$emit('primary', { preventDefault });
    expect(preventDefault).toHaveBeenCalled();
    expect(wrapper.emitted('addVariable')).toBeUndefined();
  });

  it('emits resetModal event when modal is closed', async () => {
    await findModal().vm.$emit('hidden');
    await nextTick();
    expect(findModal().props('visible')).toBe(false);
  });

  it('displays DAST variable dropdown', () => {
    expect(findVariableSelector().exists()).toBe(true);
    const items = findVariableSelector().props('items');
    expect(items.length).toBeGreaterThan(0);
  });

  it('renders the description with a link', () => {
    const description = {
      message: 'More details %{linkStart}here%{linkEnd}',
      path: 'https://example.com',
    };
    createComponent({
      variable: { id: 'DAST_AUTH_CLEAR_INPUT_FIELDS', type: 'string', description },
    });

    expect(findAllFormsGroups().at(1).attributes('label')).toBe('Value');
    expect(findLabelDescription().text()).toBe('More details here');
    expect(findLink().exists()).toBe(true);
    expect(findLink().attributes('href')).toBe(description.path);
    expect(findLink().text()).toBe('here');
  });

  it('renders the description without a link', () => {
    const description = {
      message: 'More details',
    };
    createComponent({
      variable: { id: 'DAST_AUTH_CLEAR_INPUT_FIELDS', type: 'string', description },
    });

    expect(findAllFormsGroups().at(1).attributes('label')).toBe('Value');
    expect(findLabelDescription().text()).toBe('More details');
    expect(findLink().exists()).toBe(false);
  });

  describe('on create mode', () => {
    it('displays radio buttons when a boolean variable is selected', async () => {
      createComponent();
      await findVariableSelector().vm.$emit('select', 'DAST_AUTH_CLEAR_INPUT_FIELDS');
      expect(findRadioGroup().exists()).toBe(true);
    });

    it('displays form input when variable is not boolean or selector (for non-selector type)', async () => {
      createComponent();
      await findVariableSelector().vm.$emit('select', 'DAST_ACTIVE_SCAN_TIMEOUT');
      expect(findValueInput().exists()).toBe(true);
    });

    it('displays textarea when variable type is selector', async () => {
      createComponent();
      await findVariableSelector().vm.$emit('select', 'DAST_AUTH_BEFORE_LOGIN_ACTIONS');
      expect(findFormTextArea().exists()).toBe(true);
    });

    it('dont display any form input when type is null', async () => {
      createComponent();
      await findVariableSelector().vm.$emit('select', null);
      expect(findAllFormsGroups().exists()).toBe(true);
      expect(findAllFormsGroups().length).toBe(1);
    });
  });

  describe('on edit mode', () => {
    it('displays radio buttons when a boolean variable is selected', () => {
      createComponent({ variable: { type: 'boolean' } });
      expect(findRadioGroup().exists()).toBe(true);
      expect(findAllFormRadio().length).toBe(2);
    });

    it('displays form input when variable is not boolean or selector (for non-selector type)', () => {
      createComponent({ variable: { type: 'Duration string' } });
      expect(findValueInput().exists()).toBe(true);
    });

    it('displays textarea when variable type is selector', () => {
      createComponent({ variable: { type: 'selector' } });
      expect(findFormTextArea().exists()).toBe(true);
    });

    it('does not display any form input when type is null', () => {
      createComponent({ variable: { type: null } });
      expect(findAllFormsGroups().exists()).toBe(true);
      expect(findAllFormsGroups().length).toBe(1);
    });
  });

  it('while `preSelectedVariables`, the items array should exclude those values', () => {
    const preSelectedVariables = [
      { variable: 'DAST_ACTIVE_SCAN_TIMEOUT', value: 'Duration string' },
    ];
    createComponent({
      preSelectedVariables,
    });
    expect(findVariableSelector().props('items')).not.toContain(preSelectedVariables);
  });

  it('displays variable items with secondary text as description.message', () => {
    const preSelectedVariables = [
      {
        variable: 'DAST_ACTIVE_SCAN_TIMEOUT',
        value: 'Duration string',
        description: {
          message: 'More details %{linkStart}here%{linkEnd}',
          path: 'https://example.com',
        },
      },
    ];
    createComponent({
      preSelectedVariables,
    });

    const items = findVariableSelector().props('items');
    expect(items[0].secondaryText).not.toBe('More details here');
  });
});
