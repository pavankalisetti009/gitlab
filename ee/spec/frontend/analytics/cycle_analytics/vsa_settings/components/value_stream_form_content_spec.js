import { GlAlert } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  PRESET_OPTIONS_BLANK,
  PRESET_OPTIONS_DEFAULT,
} from 'ee/analytics/cycle_analytics/vsa_settings/constants';
import CustomStageFields from 'ee/analytics/cycle_analytics/vsa_settings/components/custom_stage_fields.vue';
import DefaultStageFields from 'ee/analytics/cycle_analytics/vsa_settings/components/default_stage_fields.vue';
import ValueStreamFormContent from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content.vue';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { HTTP_STATUS_OK, HTTP_STATUS_NOT_FOUND } from '~/lib/utils/http_status';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import {
  convertObjectPropsToCamelCase,
  convertObjectPropsToSnakeCase,
} from '~/lib/utils/common_utils';
import ValueStreamFormContentActions from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content_actions.vue';
import {
  customStageEvents as stageEvents,
  defaultStageConfig,
  rawCustomStage,
  endpoints,
} from '../../mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrlWithAlerts: jest.fn(),
}));

Vue.use(Vuex);

describe('ValueStreamFormContent', () => {
  let mock;
  let wrapper = null;
  let trackingSpy = null;

  const mockValueStream = { id: 13 };
  const namespacePath = 'fake/group/path';
  const streamName = 'Cool stream';
  const formSubmissionErrors = {
    name: ['has already been taken'],
    stages: [
      {
        name: ['has already been taken'],
      },
    ],
  };

  const initialData = {
    ...mockValueStream,
    stages: [convertObjectPropsToCamelCase(rawCustomStage)],
    name: 'Editable value stream',
  };

  const fakeStore = ({ state: stateOverrides }) =>
    new Vuex.Store({
      state: {
        selectedValueStream: undefined,
        ...stateOverrides,
      },
      getters: {
        namespaceRestApiRequestPath: () => namespacePath,
      },
    });

  const createComponent = ({ props = {}, state = {} } = {}) =>
    shallowMountExtended(ValueStreamFormContent, {
      store: fakeStore({ state }),
      provide: { vsaPath: '/mockPath', namespaceFullPath: namespacePath, stageEvents },
      propsData: {
        defaultStageConfig,
        ...props,
      },
      stubs: {
        CrudComponent,
      },
    });

  const findAddStageBtn = () => wrapper.findByTestId('add-button');
  const findFormActions = () => wrapper.findComponent(ValueStreamFormContentActions);
  const findDefaultStages = () => wrapper.findAllComponents(DefaultStageFields);
  const findCustomStages = () => wrapper.findAllComponents(CustomStageFields);
  const findLastCustomStage = () => findCustomStages().wrappers.at(-1);

  const findPresetSelector = () => wrapper.findByTestId('vsa-preset-selector');
  const findRestoreButton = () => wrapper.findByTestId('vsa-reset-button');
  const findRestoreStageButton = (index) => wrapper.findByTestId(`stage-action-restore-${index}`);
  const findHiddenStages = () => wrapper.findAllByTestId('vsa-hidden-stage').wrappers;
  const findNameFormGroup = () => wrapper.findByTestId('create-value-stream-name');
  const findNameInput = () => wrapper.findByTestId('create-value-stream-name-input');
  const findSubmitErrorAlert = () => wrapper.findComponent(GlAlert);

  const clickSubmit = () => findFormActions().vm.$emit('clickPrimaryAction');
  const clickAddStage = async () => {
    findFormActions().vm.$emit('clickAddStageAction');
    await nextTick();
  };
  const clickRestoreStageAtIndex = (index) => findRestoreStageButton(index).vm.$emit('click');
  const expectStageTransitionKeys = (stages) =>
    stages.forEach((stage) => expect(stage.transitionKey).toContain('stage-'));

  const changeToDefaultStages = () =>
    findPresetSelector().vm.$emit('input', PRESET_OPTIONS_DEFAULT);
  const changeToCustomStages = () => findPresetSelector().vm.$emit('input', PRESET_OPTIONS_BLANK);

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('when creating value stream', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('has the form actions', () => {
      expect(findFormActions().props()).toMatchObject({
        isLoading: false,
        isEditing: false,
        valueStreamId: -1,
      });
    });

    describe('Preset selector', () => {
      it('has the preset button', () => {
        expect(findPresetSelector().exists()).toBe(true);
      });

      it('will toggle between the blank and default templates', async () => {
        expect(findDefaultStages()).toHaveLength(defaultStageConfig.length);
        expect(findCustomStages()).toHaveLength(0);

        await changeToCustomStages();

        expect(findDefaultStages()).toHaveLength(0);
        expect(findCustomStages()).toHaveLength(1);

        await changeToDefaultStages();

        expect(findDefaultStages()).toHaveLength(defaultStageConfig.length);
        expect(findCustomStages()).toHaveLength(0);
      });

      it('does not clear name when toggling templates', async () => {
        await findNameInput().vm.$emit('input', initialData.name);

        expect(findNameInput().attributes('value')).toBe(initialData.name);

        await changeToCustomStages();

        expect(findNameInput().attributes('value')).toBe(initialData.name);

        await changeToDefaultStages();

        expect(findNameInput().attributes('value')).toBe(initialData.name);
      });

      it('each stage has a transition key when toggling', async () => {
        await changeToCustomStages();

        expectStageTransitionKeys(wrapper.vm.stages);

        await changeToDefaultStages();

        expectStageTransitionKeys(wrapper.vm.stages);
      });

      it('does not display any hidden stages', () => {
        expect(findHiddenStages()).toHaveLength(0);
      });
    });

    describe('Add stage button', () => {
      beforeEach(() => {
        wrapper = createComponent();
      });

      it('renders add stage action correctly', () => {
        expect(findAddStageBtn().props()).toMatchObject({
          category: 'primary',
          variant: 'default',
          disabled: false,
        });
      });

      it('adds a blank custom stage when clicked', async () => {
        expect(findDefaultStages()).toHaveLength(defaultStageConfig.length);
        expect(findCustomStages()).toHaveLength(0);

        await clickAddStage();

        expect(findDefaultStages()).toHaveLength(defaultStageConfig.length);
        expect(findCustomStages()).toHaveLength(1);
      });

      it('each stage has a transition key', () => {
        expectStageTransitionKeys(wrapper.vm.stages);
      });

      it('scrolls to the last stage after adding', async () => {
        await clickAddStage();

        expect(findLastCustomStage().element.scrollIntoView).toHaveBeenCalledWith({
          behavior: 'smooth',
        });
      });
    });

    describe('field validation', () => {
      beforeEach(() => {
        wrapper = createComponent();
      });

      it('validates existing fields when clicked', async () => {
        expect(findNameFormGroup().attributes('invalid-feedback')).toBe(undefined);

        await clickAddStage();

        expect(findNameFormGroup().attributes('invalid-feedback')).toBe('Name is required');
      });

      it('does not allow duplicate stage names', async () => {
        const [firstDefaultStage] = defaultStageConfig;
        await findNameInput().vm.$emit('input', streamName);

        await clickAddStage();
        await findCustomStages().at(0).vm.$emit('input', {
          field: 'name',
          value: firstDefaultStage.name,
        });

        // Trigger the field validation
        await clickAddStage();

        expect(findCustomStages().at(0).props().errors.name).toEqual(['Stage name already exists']);
      });
    });

    describe('with valid fields', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      afterEach(() => {
        unmockTracking();
      });

      describe('form submitted successfully', () => {
        beforeEach(async () => {
          mock.onPost(endpoints.valueStreamData).replyOnce(HTTP_STATUS_OK, mockValueStream);
          wrapper = createComponent();

          await findNameInput().vm.$emit('input', streamName);
          clickSubmit();

          await waitForPromises();
        });

        it('sends a create request', () => {
          expect(mock.history.post).toHaveLength(1);
          expect(JSON.parse(mock.history.post[0].data)).toEqual({
            name: streamName,
            stages: [
              {
                custom: false,
                name: 'issue',
              },
              {
                custom: false,
                name: 'plan',
              },
              {
                custom: false,
                name: 'code',
              },
            ],
          });
        });

        it('sends tracking information', () => {
          expect(trackingSpy).toHaveBeenCalledWith(undefined, 'submit_form', {
            label: 'create_value_stream',
          });
        });

        it('form header should be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(true);
        });

        it('redirects to the new value stream page', () => {
          expect(visitUrlWithAlerts).toHaveBeenCalledWith('/mockPath?value_stream_id=13', [
            {
              id: 'vsa-settings-form-submission-success',
              message: `'${streamName}' Value Stream has been successfully created.`,
              variant: 'success',
            },
          ]);
        });
      });

      describe('form submission fails', () => {
        beforeEach(async () => {
          mock.onPost(endpoints.valueStreamData).replyOnce(HTTP_STATUS_NOT_FOUND, {
            payload: { errors: formSubmissionErrors },
          });

          wrapper = createComponent();

          await findNameInput().vm.$emit('input', streamName);
          clickSubmit();

          await waitForPromises();
        });

        it('sends a create request', () => {
          expect(mock.history.post).toHaveLength(1);
        });

        it('does not clear the name field', () => {
          expect(findNameInput().attributes('value')).toBe(streamName);
        });

        it('does not redirect to the new value stream page', () => {
          expect(visitUrlWithAlerts).not.toHaveBeenCalled();
        });

        it('form actions should not be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(false);
        });

        it('renders errors for the name field', () => {
          expect(findNameFormGroup().attributes('invalid-feedback')).toBe(
            formSubmissionErrors.name[0],
          );
        });

        it('renders a dismissible generic alert error', async () => {
          expect(findSubmitErrorAlert().exists()).toBe(true);
          await findSubmitErrorAlert().vm.$emit('dismiss');
          expect(findSubmitErrorAlert().exists()).toBe(false);
        });
      });
    });
  });

  describe('when editing value stream', () => {
    const stageCount = initialData.stages.length;
    beforeEach(() => {
      wrapper = createComponent({
        props: {
          initialData,
          isEditing: true,
        },
        state: {
          selectedValueStream: mockValueStream,
        },
      });
    });

    it('does not have the preset button', () => {
      expect(findPresetSelector().exists()).toBe(false);
    });

    it('passes isEditing=true to form actions', () => {
      expect(findFormActions().props().isEditing).toBe(true);
    });

    it('passes value stream ID to form actions', () => {
      expect(findFormActions().props().valueStreamId).toBe(mockValueStream.id);
    });

    it('does not display any hidden stages', () => {
      expect(findHiddenStages()).toHaveLength(0);
    });

    it('each stage has a transition key', () => {
      expectStageTransitionKeys(wrapper.vm.stages);
    });

    describe('restore defaults button', () => {
      it('restores the original name', async () => {
        const newName = 'name';

        await findNameInput().vm.$emit('input', newName);

        expect(findNameInput().attributes('value')).toBe(newName);

        await findRestoreButton().vm.$emit('click');

        expect(findNameInput().attributes('value')).toBe(initialData.name);
      });

      it('will clear the form fields', async () => {
        expect(findCustomStages()).toHaveLength(stageCount);

        await clickAddStage();

        expect(findCustomStages()).toHaveLength(stageCount + 1);

        await findRestoreButton().vm.$emit('click');

        expect(findCustomStages()).toHaveLength(stageCount);
      });
    });

    describe('with hidden stages', () => {
      const hiddenStages = defaultStageConfig.map((s) => ({ ...s, hidden: true }));

      beforeEach(() => {
        wrapper = createComponent({
          props: {
            initialData: { ...initialData, stages: [...initialData.stages, ...hiddenStages] },
            isEditing: true,
          },
        });
      });

      it('displays hidden each stage', () => {
        expect(findHiddenStages()).toHaveLength(hiddenStages.length);

        findHiddenStages().forEach((s) => {
          expect(s.text()).toContain('Restore stage');
        });
      });

      it('when `Restore stage` is clicked, the stage is restored', async () => {
        expect(findHiddenStages()).toHaveLength(hiddenStages.length);
        expect(findDefaultStages()).toHaveLength(0);
        expect(findCustomStages()).toHaveLength(stageCount);

        await clickRestoreStageAtIndex(1);

        expect(findHiddenStages()).toHaveLength(hiddenStages.length - 1);
        expect(findDefaultStages()).toHaveLength(1);
        expect(findCustomStages()).toHaveLength(stageCount);
      });

      it('when a stage is restored it has a transition key', async () => {
        await clickRestoreStageAtIndex(1);

        expect(wrapper.vm.stages[stageCount].transitionKey).toContain(
          `stage-${hiddenStages[1].name}-`,
        );
      });
    });

    describe('Add stage button', () => {
      beforeEach(() => {
        wrapper = createComponent({
          props: {
            initialData,
            isEditing: true,
          },
        });
      });

      it('adds a blank custom stage when clicked', async () => {
        expect(findCustomStages()).toHaveLength(stageCount);

        await clickAddStage();

        expect(findCustomStages()).toHaveLength(stageCount + 1);
      });

      it('validates existing fields when clicked', async () => {
        expect(findNameInput().props().state).toBe(true);

        await findNameInput().vm.$emit('input', '');
        await clickAddStage();

        expect(findNameInput().props().state).toBe(false);
      });
    });

    describe('with valid fields', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      afterEach(() => {
        unmockTracking();
      });

      describe('form submitted successfully', () => {
        beforeEach(() => {
          mock.onPut(endpoints.valueStreamData).replyOnce(HTTP_STATUS_OK, mockValueStream);

          wrapper = createComponent({
            props: {
              initialData,
              isEditing: true,
            },
            state: {
              selectedValueStream: mockValueStream,
            },
          });

          clickSubmit();
          return waitForPromises();
        });

        it('sends an update request', () => {
          expect(mock.history.put).toHaveLength(1);
          expect(mock.history.put[0].url).toBe(
            '/fake/group/path/-/analytics/value_stream_analytics/value_streams/13',
          );
          expect(JSON.parse(mock.history.put[0].data)).toEqual({
            name: initialData.name,
            stages: initialData.stages.map((stage) =>
              convertObjectPropsToSnakeCase(stage, { deep: true }),
            ),
          });
        });

        it('form actions should be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(true);
        });

        it('redirects to the updated value stream page', () => {
          expect(visitUrlWithAlerts).toHaveBeenCalledWith('/mockPath?value_stream_id=13', [
            {
              id: 'vsa-settings-form-submission-success',
              message: `'${initialData.name}' Value Stream has been successfully saved.`,
              variant: 'success',
            },
          ]);
        });

        it('sends tracking information', () => {
          expect(trackingSpy).toHaveBeenCalledWith(undefined, 'submit_form', {
            label: 'edit_value_stream',
          });
        });
      });

      describe('form submission fails', () => {
        beforeEach(() => {
          mock.onPut(endpoints.valueStreamData).replyOnce(HTTP_STATUS_NOT_FOUND, {
            payload: { errors: formSubmissionErrors },
          });

          wrapper = createComponent({
            props: {
              initialData,
              isEditing: true,
            },
            state: {
              selectedValueStream: mockValueStream,
            },
          });

          clickSubmit();
          return waitForPromises();
        });

        it('sends an update request', () => {
          expect(mock.history.put).toHaveLength(1);
        });

        it('does not clear the name field', () => {
          const { name } = initialData;

          expect(findNameInput().attributes('value')).toBe(name);
        });

        it('does not redirect to the value stream page', () => {
          expect(visitUrlWithAlerts).not.toHaveBeenCalled();
        });

        it('form actions should not be in loading state', () => {
          expect(findFormActions().props('isLoading')).toBe(false);
        });

        it('renders errors for the name field', () => {
          expect(findNameFormGroup().attributes('invalid-feedback')).toBe(
            formSubmissionErrors.name[0],
          );
        });

        it('renders errors for a custom stage field', () => {
          expect(findCustomStages().at(0).props().errors.name[0]).toBe(
            formSubmissionErrors.stages[0].name[0],
          );
        });

        it('renders a dismissible generic alert error', async () => {
          expect(findSubmitErrorAlert().exists()).toBe(true);
          await findSubmitErrorAlert().vm.$emit('dismiss');
          expect(findSubmitErrorAlert().exists()).toBe(false);
        });
      });
    });
  });
});
