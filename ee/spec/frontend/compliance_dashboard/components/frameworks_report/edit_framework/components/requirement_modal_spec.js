import {
  GlModal,
  GlFormInput,
  GlFormTextarea,
  GlBadge,
  GlTooltip,
  GlCollapsibleListbox,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RequirementModal from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirement_modal.vue';
import {
  emptyRequirement,
  requirementEvents,
} from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/constants';
import waitForPromises from 'helpers/wait_for_promises';
import {
  mockGitLabStandardControls,
  mockRequirements,
} from 'ee_jest/compliance_dashboard/mock_data';

describe('RequirementModal', () => {
  let wrapper;

  const defaultProps = {
    requirement: { ...emptyRequirement, index: null },
    gitlabStandardControls: mockGitLabStandardControls,
    isNewFramework: true,
  };

  const mockEvent = {
    preventDefault: jest.fn(),
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findNameInput = () => wrapper.findComponent(GlFormInput);
  const findNameInputGroup = () => wrapper.findByTestId('name-input-group');
  const findDescriptionTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findDescriptionInputGroup = () => wrapper.findByTestId('description-input-group');
  const submitModalForm = () => findModal().vm.$emit('primary', mockEvent);
  const findAddControlButton = () => wrapper.findByTestId('add-control-button');
  const findControlSelectors = () => wrapper.findAllComponents(GlCollapsibleListbox);
  const findControlAtIndex = (index) => wrapper.findByTestId(`control-select-${index}`);
  const findControlsBadge = () => wrapper.findComponent(GlBadge);
  const findTooltip = () => wrapper.findComponent(GlTooltip);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(RequirementModal, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const addControl = async (controlId = null, index = 0) => {
    await findAddControlButton().vm.$emit('click');
    await nextTick();
    if (controlId !== null) {
      const controlSelector = findControlAtIndex(index);
      if (controlSelector.exists()) {
        await controlSelector.vm.$emit('select', controlId);
        await nextTick();
      }
    }
  };

  const fillForm = async (name, description, controls = []) => {
    if (name !== undefined) {
      await findNameInput().vm.$emit('input', name);
    }
    if (description !== undefined) {
      await findDescriptionTextarea().vm.$emit('input', description);
    }
    for (const [index, controlId] of controls.entries()) {
      // eslint-disable-next-line no-await-in-loop
      await addControl(controlId, index);
    }
  };

  describe('Rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the modal', () => {
      expect(findModal().exists()).toBe(true);
    });

    it('renders the name input field', () => {
      expect(findNameInput().exists()).toBe(true);
    });

    it('renders the description textarea', () => {
      expect(findDescriptionTextarea().exists()).toBe(true);
    });

    it('renders the correct title for a new requirement', () => {
      expect(findModal().attributes('title')).toBe('Create new requirement');
    });

    it('renders the controls selection UI', () => {
      expect(findAddControlButton().exists()).toBe(true);
    });

    it('shows the initial controls count as 0', () => {
      expect(findControlsBadge().text()).toBe('0');
    });
  });

  describe('Interaction', () => {
    beforeEach(() => {
      createComponent();
    });

    it('allows adding a control', async () => {
      expect(findControlSelectors()).toHaveLength(1);
      await addControl();
      expect(findControlSelectors()).toHaveLength(2);
    });

    it('updates the controls count when controls are selected', async () => {
      await addControl('scanner_sast_running');
      expect(findControlsBadge().text()).toBe('1');
    });

    it('prevents adding more than 5 controls', async () => {
      for (let i = 0; i < 5; i += 1) {
        // eslint-disable-next-line no-await-in-loop
        await addControl();
      }
      expect(findControlSelectors()).toHaveLength(5);
      expect(findAddControlButton().attributes('disabled')).toBeDefined();
      expect(findTooltip().exists()).toBe(true);
      expect(findTooltip().attributes('title')).toBe('You can create a maximum of 5 controls');
    });

    it('emits create event with requirement data including selected controls', async () => {
      const name = 'Test Name';
      const description = 'Test Description';
      await fillForm(name, description, ['scanner_sast_running', 'default_branch_protected']);
      submitModalForm();
      await waitForPromises();
      expect(wrapper.emitted(requirementEvents.create)).toMatchObject([
        [
          {
            index: null,
            requirement: {
              description,
              name,
            },
          },
        ],
      ]);
    });

    it('filters out selected controls from already selected selectors', async () => {
      await addControl('scanner_sast_running');
      await addControl();
      const secondControlItems = findControlAtIndex(1).props('items');
      expect(secondControlItems).not.toEqual(
        expect.arrayContaining([expect.objectContaining({ value: 'scanner_sast_running' })]),
      );
    });
  });

  it('emits update event with correct data including controls when editing an existing requirement', async () => {
    createComponent({
      requirement: { ...mockRequirements[0], index: 0 },
      isNewFramework: false,
      gitlabStandardControls: mockGitLabStandardControls,
    });
    await fillForm('Updated Name', 'Updated Description', [
      'scanner_sast_running',
      'default_branch_protected',
    ]);
    submitModalForm();
    await waitForPromises();
    expect(wrapper.emitted(requirementEvents.update)).toEqual([
      [
        {
          requirement: {
            name: 'Updated Name',
            description: 'Updated Description',
            id: mockRequirements[0].id,
            __typename: 'ComplianceManagement::Requirement',
            complianceRequirementsControls: {
              nodes: [],
            },
            stagedControls: [
              {
                controlType: 'internal',
                displayName: 'SAST Running',
                expression: '{"field":"scanner_sast_running","operator":"=","value":true}',
                id: undefined,
                name: 'scanner_sast_running',
              },
              {
                controlType: 'internal',
                displayName: 'Default branch protected',
                expression: '{"field":"default_branch_protected","operator":"=","value":true}',
                id: undefined,
                name: 'default_branch_protected',
              },
            ],
          },
          index: 0,
        },
      ],
    ]);
  });

  describe('Validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('validates that name is required', async () => {
      submitModalForm();
      await waitForPromises();
      expect(findNameInputGroup().attributes('state')).toBeUndefined();
    });

    it('validates that description is required', async () => {
      submitModalForm();
      await waitForPromises();
      expect(findDescriptionInputGroup().attributes('state')).toBeUndefined();
    });

    it('validates that the form is valid when fields are filled', async () => {
      const name = 'Test Name';
      const description = 'Test Description';
      await fillForm(name, description);
      submitModalForm();
      await waitForPromises();
      expect(findNameInputGroup().attributes('state')).toBe('true');
      expect(findDescriptionInputGroup().attributes('state')).toBe('true');
    });

    it('validates that name and description cannot be empty strings', async () => {
      await fillForm(' ', ' ');
      submitModalForm();
      await waitForPromises();
      expect(findNameInputGroup().attributes('state')).toBeUndefined();
      expect(findDescriptionInputGroup().attributes('state')).toBeUndefined();
    });

    it('emits save event with requirement data when form is valid', async () => {
      const name = 'Test Name';
      const description = 'Test Description';
      await fillForm(name, description);
      submitModalForm();
      await waitForPromises();
      expect(wrapper.emitted(requirementEvents.create)).toEqual([
        [
          {
            index: null,
            requirement: {
              description,
              name,
              stagedControls: [],
            },
          },
        ],
      ]);
    });
  });

  describe('External Controls', () => {
    beforeEach(() => {
      createComponent();
    });

    const findAddExternalControlButton = () => wrapper.findByTestId('add-external-control-button');
    const findExternalUrlInput = (index) => wrapper.findByTestId(`external-url-input-${index}`);
    const findExternalSecretInput = (index) =>
      wrapper.findByTestId(`external-secret-input-${index}`);

    it('renders external control form when adding external control', async () => {
      await findAddExternalControlButton().vm.$emit('click');
      await nextTick();
      expect(findExternalUrlInput(1).exists()).toBe(true);
      expect(findExternalSecretInput(1).exists()).toBe(true);
    });

    it('saves requirement with external control data', async () => {
      await findAddExternalControlButton().vm.$emit('click');
      await nextTick();

      const externalUrl = 'https://api.example.com';
      const secretToken = 'secret123';

      await findExternalUrlInput(1).vm.$emit('input', externalUrl);
      await findExternalSecretInput(1).vm.$emit('input', secretToken);
      await fillForm('Test Name', 'Test Description');

      submitModalForm();
      await waitForPromises();

      expect(wrapper.emitted(requirementEvents.create)[0][0].requirement.stagedControls).toEqual([
        {
          controlType: 'external',
          externalUrl,
          secretToken,
          name: 'external_control',
          expression: null,
        },
      ]);
    });

    it('loads and displays existing external controls', async () => {
      const existingRequirement = {
        ...mockRequirements[0],
        complianceRequirementsControls: {
          nodes: [
            {
              id: '1',
              name: 'external_control',
              controlType: 'external',
              externalUrl: 'https://api.example.com',
              secretToken: 'secret123',
            },
          ],
        },
      };

      createComponent({ requirement: existingRequirement });
      await nextTick();

      expect(findExternalUrlInput(0).attributes('value')).toBe('https://api.example.com');
      expect(findExternalSecretInput(0).exists()).toBe(true);
    });

    it('allows mixing external and internal controls', async () => {
      await findAddExternalControlButton().vm.$emit('click');
      await addControl('scanner_sast_running', 1);
      await nextTick();

      expect(findExternalUrlInput(1).exists()).toBe(true);
      expect(findControlAtIndex(2).exists()).toBe(true);
    });

    it('respects maximum control limit for external controls', async () => {
      for (let i = 0; i < 5; i += 1) {
        // eslint-disable-next-line no-await-in-loop
        await findAddExternalControlButton().vm.$emit('click');
      }

      expect(findAddExternalControlButton().attributes('disabled')).toBeDefined();
    });

    describe('External Control Validations', () => {
      beforeEach(() => {
        createComponent();
      });

      const findExternalUrlInputGroup = (index) =>
        wrapper.findByTestId(`external-url-input-group-${index}`);
      const findExternalSecretInputGroup = (index) =>
        wrapper.findByTestId(`external-secret-input-group-${index}`);

      it.each([' ', 'not-a-url', 'api.example.com', 'ftp://api.example.com'])(
        'flags %s as an invalid URL',
        async (value) => {
          await findAddExternalControlButton().vm.$emit('click');
          await nextTick();

          await findExternalUrlInput(1).vm.$emit('input', value);
          await fillForm('Test Name', 'Test Description');
          submitModalForm();
          await waitForPromises();
          await nextTick();

          expect(findExternalUrlInput(1).attributes('state')).toBeUndefined();
          expect(wrapper.emitted(requirementEvents.create)).toBeUndefined();
        },
      );

      it.each(['https://api.example.com', 'https://api.example.com'])(
        'flags %s as a valid URL',
        async (value) => {
          await findAddExternalControlButton().vm.$emit('click');
          await nextTick();

          await findExternalUrlInput(1).vm.$emit('input', value);
          await fillForm('Test Name', 'Test Description');
          submitModalForm();
          await waitForPromises();
          await nextTick();

          expect(findExternalUrlInputGroup(1).attributes('state')).toBe('true');
        },
      );

      it('validates secret token is not empty', async () => {
        await findAddExternalControlButton().vm.$emit('click');
        await nextTick();

        await findExternalUrlInput(1).vm.$emit('input', 'https://api.example.com');
        await findExternalSecretInput(1).vm.$emit('input', '');
        await fillForm('Test Name', 'Test Description');
        submitModalForm();
        await waitForPromises();
        await nextTick();

        expect(findExternalSecretInput(1).attributes('state')).toBeUndefined();
        expect(wrapper.emitted(requirementEvents.create)).toBeUndefined();

        await findExternalSecretInput(1).vm.$emit('input', 'secret123');
        submitModalForm();
        await waitForPromises();
        await nextTick();

        expect(findExternalSecretInputGroup(1).attributes('state')).toBe('true');
      });

      it('flags multiple external controls as invalid if any are invalid', async () => {
        await findAddExternalControlButton().vm.$emit('click');
        await findAddExternalControlButton().vm.$emit('click');
        await nextTick();

        await findExternalUrlInput(1).vm.$emit('input', 'https://api1.example.com');
        await findExternalSecretInput(1).vm.$emit('input', 'secret1');

        await findExternalUrlInput(2).vm.$emit('input', 'not-a-url');
        await findExternalSecretInput(2).vm.$emit('input', 'secret2');

        await fillForm('Test Name', 'Test Description');
        submitModalForm();
        await waitForPromises();
        await nextTick();

        expect(findExternalUrlInputGroup(1).attributes('state')).toBe('true');
        expect(findExternalUrlInputGroup(2).attributes('state')).toBeUndefined();
        expect(wrapper.emitted(requirementEvents.create)).toBeUndefined();
      });

      it('flags multiple external controls as valid if all are valid', async () => {
        await findAddExternalControlButton().vm.$emit('click');
        await findAddExternalControlButton().vm.$emit('click');
        await nextTick();

        await findExternalUrlInput(1).vm.$emit('input', 'https://api1.example.com');
        await findExternalSecretInput(1).vm.$emit('input', 'secret1');

        await findExternalUrlInput(2).vm.$emit('input', 'https://api2.example.com');
        await findExternalSecretInput(2).vm.$emit('input', 'secret2');

        await fillForm('Test Name', 'Test Description');
        submitModalForm();
        await waitForPromises();
        await nextTick();

        expect(findExternalUrlInputGroup(1).attributes('state')).toBe('true');
        expect(findExternalUrlInputGroup(2).attributes('state')).toBe('true');
        expect(wrapper.emitted(requirementEvents.create)).toBeDefined();
      });

      it('validates internal controls are valid', async () => {
        await addControl('scanner_sast_running');
        await fillForm('Test Name', 'Test Description');
        submitModalForm();
        await waitForPromises();
        await nextTick();

        expect(wrapper.emitted(requirementEvents.create)).toBeDefined();
      });
    });
  });

  describe('Control expression handling', () => {
    beforeEach(() => {
      createComponent();
      jest.spyOn(wrapper.vm, 'handleSubmit').mockImplementation(() => {});
    });

    it('preserves expression when it is already a string', () => {
      wrapper.vm.controls = [
        {
          name: 'test_control',
          expression: '{"field":"test_control","operator":"=","value":true}',
        },
      ];

      wrapper.vm.handleSubmit(mockEvent);
      expect(wrapper.vm.handleSubmit).toHaveBeenCalled();

      const processedControls = wrapper.vm.controls.map((control) => {
        if (!control) return null;
        if (control.expression) {
          if (typeof control.expression === 'string') {
            return {
              ...control,
              expression: control.expression,
            };
          }
        }
        return control;
      });

      expect(processedControls[0].expression).toBe(
        '{"field":"test_control","operator":"=","value":true}',
      );
    });

    it('stringifies expression when it is an object', () => {
      wrapper.vm.controls = [
        {
          name: 'test_control',
          expression: { field: 'test_control', operator: '=', value: true },
        },
      ];

      wrapper.vm.handleSubmit(mockEvent);

      const processedControls = wrapper.vm.controls.map((control) => {
        if (!control) return null;
        if (control.expression) {
          if (typeof control.expression === 'string') {
            return {
              ...control,
              expression: control.expression,
            };
          }
          return {
            ...control,
            expression: JSON.stringify(control.expression),
          };
        }
        return control;
      });

      expect(processedControls[0].expression).toBe(
        '{"field":"test_control","operator":"=","value":true}',
      );
    });
  });
});
