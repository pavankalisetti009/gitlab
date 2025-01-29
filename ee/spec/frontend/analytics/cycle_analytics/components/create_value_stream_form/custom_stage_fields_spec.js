import { nextTick } from 'vue';
import { GlAlert, GlFormInput } from '@gitlab/ui';
import CustomStageFields from 'ee/analytics/cycle_analytics/components/create_value_stream_form/custom_stage_fields.vue';
import CustomStageEventField from 'ee/analytics/cycle_analytics/components/create_value_stream_form/custom_stage_event_field.vue';
import CustomStageEventLabelField from 'ee/analytics/cycle_analytics/components/create_value_stream_form/custom_stage_event_label_field.vue';
import StageFieldActions from 'ee/analytics/cycle_analytics/components/create_value_stream_form/stage_field_actions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  customStageEvents as stageEvents,
  labelStartEvent,
  labelEndEvent,
  customStageEndEvents as endEvents,
} from '../../mock_data';
import { emptyState, firstLabel } from './mock_data';

const formatStartEventOpts = (_events) =>
  _events
    .filter((ev) => ev.canBeStartEvent)
    .map(({ name: text, identifier: value }) => ({ text, value }));

const formatEndEventOpts = (_events) =>
  _events
    .filter((ev) => !ev.canBeStartEvent)
    .map(({ name: text, identifier: value }) => ({ text, value }));

const startEventOptions = formatStartEventOpts(stageEvents);
const endEventOptions = formatEndEventOpts(stageEvents);

describe('CustomStageFields', () => {
  let wrapper = null;

  const createComponent = ({ stage = emptyState, errors = {}, stubs = {}, props = {} } = {}) => {
    wrapper = shallowMountExtended(CustomStageFields, {
      propsData: {
        stage,
        errors,
        stageEvents,
        index: 0,
        totalStages: 3,
        stageLabel: 'Stage 1',
        ...props,
      },
      stubs: {
        'labels-selector': false,
        ...stubs,
      },
    });
  };

  const findName = (index = 0) => wrapper.findByTestId(`custom-stage-name-${index}`);
  const findFormError = () => wrapper.findComponent(GlAlert);
  const findStartEventLabel = (index = 0) =>
    wrapper.findByTestId(`custom-stage-start-event-label-${index}`);
  const findEndEventLabel = (index = 0) =>
    wrapper.findByTestId(`custom-stage-end-event-label-${index}`);
  const findNameField = () => findName().findComponent(GlFormInput);
  const findStartEventField = () => wrapper.findAllComponents(CustomStageEventField).at(0);
  const findEndEventField = () => wrapper.findAllComponents(CustomStageEventField).at(1);
  const findStartEventLabelField = () =>
    wrapper.findAllComponents(CustomStageEventLabelField).at(0);
  const findEndEventLabelField = () => wrapper.findAllComponents(CustomStageEventLabelField).at(1);
  const findStageFieldActions = () => wrapper.findComponent(StageFieldActions);

  beforeEach(() => {
    createComponent();
  });

  describe.each([
    ['Name', findNameField, undefined, 'value', undefined],
    ['Start event', findStartEventField, undefined, 'defaultdropdowntext', 'Select start event'],
    ['End event', findEndEventField, 'true', 'defaultdropdowntext', 'Select end event'],
    // eslint-disable-next-line max-params
  ])('Default state', (field, finder, fieldDisabledValue, valueAttribute, value) => {
    it(`field '${field}' is disabled ${fieldDisabledValue ? 'true' : 'false'}`, () => {
      const $el = finder();
      expect($el.exists()).toBe(true);
      expect($el.attributes().disabled).toBe(fieldDisabledValue);
      expect($el.attributes(valueAttribute)).toBe(value);
    });
  });

  describe.each([
    ['Start event label', findStartEventLabel],
    ['End event label', findEndEventLabel],
    ['Form error alert', findFormError],
  ])('Default state', (field, finder) => {
    it(`field '${field}' is hidden by default`, () => {
      expect(finder().exists()).toBe(false);
    });
  });

  describe('Fields', () => {
    it('emit input event when a field is changed', () => {
      expect(wrapper.emitted('input')).toBeUndefined();
      findNameField().vm.$emit('input', 'Cool new stage');

      expect(wrapper.emitted('input')[0]).toEqual([{ field: 'name', value: 'Cool new stage' }]);
    });
  });

  describe('Name field', () => {
    it('will display name field in a valid state', () => {
      expect(findName().attributes('state')).toBe('true');
      expect(findName().attributes('invalid-feedback')).toBeUndefined();
      expect(findNameField().attributes('state')).toBe('true');
    });

    describe('invalid state', () => {
      beforeEach(() => {
        createComponent({ errors: { name: ['Please enter a name'] } });
      });

      it('will display name field in an invalid state', () => {
        expect(findNameField().attributes('state')).toBeUndefined();
        expect(findName().attributes('state')).toBeUndefined();
        expect(findName().attributes('invalid-feedback')).toBe('Please enter a name');
      });

      it.each`
        field            | finder                 | expectedProps
        ${'Start event'} | ${findStartEventField} | ${{ identifierError: '', isIdentifierValid: true }}
        ${'End event'}   | ${findEndEventField}   | ${{ identifierError: '', isIdentifierValid: true }}
      `('will display $field in a valid state', ({ finder, expectedProps }) => {
        expect(finder().props()).toMatchObject(expectedProps);
      });
    });
  });

  describe('Start event', () => {
    beforeEach(() => {
      createComponent();
    });

    it('will display start event in a valid state', () => {
      expect(findStartEventField().props()).toMatchObject({
        identifierError: '',
        isIdentifierValid: true,
      });
    });

    it('selects the correct start events for the start events dropdown', () => {
      expect(findStartEventField().props('eventsList')).toEqual(startEventOptions);
    });

    it('does not select end events for the start events dropdown', () => {
      expect(findStartEventField().props('eventsList')).not.toEqual(endEventOptions);
    });

    describe('invalid state', () => {
      beforeEach(() => {
        createComponent({ errors: { startEventIdentifier: ['Select a start event'] } });
      });

      it('will display start event in an invalid state', () => {
        expect(findStartEventField().props()).toMatchObject({
          identifierError: 'Select a start event',
          isIdentifierValid: false,
        });
      });

      it('will display name field in a valid state', () => {
        expect(findName().attributes('state')).toBe('true');
        expect(findName().attributes('invalid-feedback')).toBeUndefined();
        expect(findNameField().attributes('state')).toBe('true');
      });

      it('will display end event in a valid state', () => {
        expect(findEndEventField().props()).toMatchObject({
          identifierError: '',
          isIdentifierValid: true,
        });
      });
    });

    describe('start event label', () => {
      beforeEach(() => {
        createComponent({
          stage: {
            startEventIdentifier: labelStartEvent.identifier,
          },
        });
      });

      it('will display the start event label field if a label event is selected', () => {
        expect(findStartEventLabelField().props()).toMatchObject({
          labelError: '',
          isLabelValid: true,
        });
      });

      it('will emit the `input` event when the start event label field when selected', () => {
        expect(wrapper.emitted('input')).toBeUndefined();

        findStartEventLabelField().vm.$emit('update-label', firstLabel);

        expect(wrapper.emitted('input')[0]).toEqual([
          { field: 'startEventLabelId', value: firstLabel.id },
        ]);
      });

      it('will show an error alert emitted from the label field', async () => {
        const message = 'test';
        findStartEventLabelField().vm.$emit('error', message);

        await nextTick();
        expect(findFormError().text()).toBe(message);
      });

      describe('invalid state', () => {
        beforeEach(() => {
          createComponent({
            stage: {
              startEventIdentifier: labelStartEvent.identifier,
            },
            errors: { startEventLabelId: ['Select a start event label'] },
          });
        });

        it('will display the start event label field in an invalid state', () => {
          expect(findStartEventLabelField().props()).toMatchObject({
            labelError: 'Select a start event label',
            isLabelValid: false,
          });
        });

        it('will display name field in a valid state', () => {
          expect(findName().attributes('state')).toBe('true');
          expect(findName().attributes('invalid-feedback')).toBeUndefined();
          expect(findNameField().attributes('state')).toBe('true');
        });

        it.each`
          field            | finder                 | expectedProps
          ${'Start event'} | ${findStartEventField} | ${{ identifierError: '', isIdentifierValid: true }}
          ${'End event'}   | ${findEndEventField}   | ${{ identifierError: '', isIdentifierValid: true }}
        `('will display $field in a valid state', ({ finder, expectedProps }) => {
          expect(finder().props()).toMatchObject(expectedProps);
        });
      });
    });
  });

  describe('End event', () => {
    const possibleEndEvents = endEvents.filter((ev) =>
      labelStartEvent.allowedEndEvents.includes(ev.identifier),
    );

    const allowedEndEventOpts = formatEndEventOpts(possibleEndEvents);

    beforeEach(() => {
      createComponent();
    });

    it('will display end event in a valid state', () => {
      expect(findEndEventField().props()).toMatchObject({
        identifierError: '',
        isIdentifierValid: true,
      });
    });

    it('selects the end events based on the start event', () => {
      expect(findEndEventField().props('eventsList')).toEqual(allowedEndEventOpts);
    });

    it('does not select start events for the end events dropdown', () => {
      expect(findEndEventField().props('eventsList')).not.toEqual(startEventOptions);
    });

    describe('invalid state', () => {
      beforeEach(() => {
        createComponent({ errors: { endEventIdentifier: ['Select a start event first'] } });
      });

      it('will display end event in an invalid state', () => {
        expect(findEndEventField().props()).toMatchObject({
          identifierError: 'Select a start event first',
          isIdentifierValid: false,
        });
      });

      it('will display name field in a valid state', () => {
        expect(findName().attributes('state')).toBe('true');
        expect(findName().attributes('invalid-feedback')).toBeUndefined();
        expect(findNameField().attributes('state')).toBe('true');
      });

      it('will display start event in a valid state', () => {
        expect(findStartEventField().props()).toMatchObject({
          identifierError: '',
          isIdentifierValid: true,
        });
      });
    });

    describe('end event label', () => {
      beforeEach(() => {
        createComponent({
          stage: {
            startEventIdentifier: labelStartEvent.identifier,
            endEventIdentifier: labelEndEvent.identifier,
          },
        });
      });

      it('will display the end event label field if a label event is selected', () => {
        expect(findEndEventLabelField().props()).toMatchObject({
          labelError: '',
          isLabelValid: true,
        });
      });

      it('will emit the `input` event when the start event label field when selected', () => {
        expect(wrapper.emitted('input')).toBeUndefined();

        findEndEventLabelField().vm.$emit('update-label', firstLabel);

        expect(wrapper.emitted('input')[0]).toEqual([
          { field: 'endEventLabelId', value: firstLabel.id },
        ]);
      });

      it('will show an error alert emitted from the label field', async () => {
        const message = 'test';
        findEndEventLabelField().vm.$emit('error', message);

        await nextTick();
        expect(findFormError().text()).toBe(message);
      });

      describe('invalid state', () => {
        beforeEach(() => {
          createComponent({
            stage: {
              startEventIdentifier: labelStartEvent.identifier,
              endEventIdentifier: labelEndEvent.identifier,
            },
            errors: { endEventLabelId: ['Select an end event label'] },
          });
        });

        it('will display the end event label field in an invalid state', () => {
          expect(findEndEventLabelField().props()).toMatchObject({
            labelError: 'Select an end event label',
            isLabelValid: false,
          });
        });

        it('will display name field in a valid state', () => {
          expect(findName().attributes('state')).toBe('true');
          expect(findName().attributes('invalid-feedback')).toBeUndefined();
          expect(findNameField().attributes('state')).toBe('true');
        });

        it.each`
          field            | finder                 | expectedProps
          ${'Start event'} | ${findStartEventField} | ${{ identifierError: '', isIdentifierValid: true }} | ${'Start event label'} | ${findStartEventLabelField} | ${{ labelError: '', isLabelValid: true }}
          ${'End event'}   | ${findEndEventField}   | ${{ identifierError: '', isIdentifierValid: true }}
        `('will display $field in a valid state', ({ finder, expectedProps }) => {
          expect(finder().props()).toMatchObject(expectedProps);
        });
      });
    });
  });

  describe('Stage actions', () => {
    it('will display the stage actions component', () => {
      expect(findStageFieldActions().exists()).toBe(true);
    });

    describe('with only 1 stage', () => {
      beforeEach(() => {
        createComponent({ props: { totalStages: 1 } });
      });

      it('does not display the stage actions component', () => {
        expect(findStageFieldActions().exists()).toBe(false);
      });
    });
  });

  describe('Editing', () => {
    beforeEach(() => {
      createComponent({
        stage: {
          name: 'lol',
          startEventIdentifier: labelStartEvent.identifier,
          endEventIdentifier: labelEndEvent.identifier,
        },
      });
    });

    describe.each([
      ['Name', findNameField, 'value', 'lol'],
      ['Start event', findStartEventField, 'initialvalue', 'issue_label_added'],
      ['End event', findEndEventField, 'initialvalue', 'issue_label_added'],
      // eslint-disable-next-line max-params
    ])('will initialize the field', (field, finder, valueAttribute, value) => {
      it(`'${field}' to value '${value}'`, () => {
        const $el = finder();
        expect($el.exists()).toBe(true);

        expect($el.attributes(valueAttribute)).toBe(value);
      });
    });
  });
});
