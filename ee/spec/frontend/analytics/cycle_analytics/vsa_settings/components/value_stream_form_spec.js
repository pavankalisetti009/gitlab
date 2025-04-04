import Vue from 'vue';
import { GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import ValueStreamForm from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form.vue';
import ValueStreamFormContent from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  rawCustomStage,
  valueStreams,
  defaultStageConfig,
} from 'ee_jest/analytics/cycle_analytics/mock_data';

Vue.use(Vuex);

const [valueStream] = valueStreams;
const camelCustomStage = convertObjectPropsToCamelCase(rawCustomStage);
const stages = [camelCustomStage];
const initialData = { name: '', stages: [] };

describe('ValueStreamForm', () => {
  let wrapper = null;

  const fakeStore = ({ state }) =>
    new Vuex.Store({
      state: {
        defaultStageConfig,
        isLoading: false,
        isFetchingGroupStages: false,
        ...state,
      },
    });

  const createComponent = ({ props = {}, state = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ValueStreamForm, {
      store: fakeStore({ state }),
      provide: {
        valueStream: undefined,
        ...provide,
      },
      propsData: {
        defaultStageConfig,
        ...props,
      },
    });
  };

  const findFormContent = () => wrapper.findComponent(ValueStreamFormContent);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  describe('default state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the form content component', () => {
      expect(findFormContent().props()).toMatchObject({
        defaultStageConfig,
        initialData,
        isEditing: false,
      });
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('when editing', () => {
    beforeEach(() => {
      createComponent({
        props: { isEditing: true },
        provide: { valueStream },
        state: { stages },
      });
    });

    it('renders form content component correctly', () => {
      const populatedInitialData = {
        id: valueStream.id,
        name: valueStream.name,
        stages: [
          camelCustomStage,
          ...defaultStageConfig.map(({ custom, name }) => ({ custom, name, hidden: true })),
        ],
      };

      expect(findFormContent().props()).toMatchObject({
        defaultStageConfig,
        initialData: populatedInitialData,
        isEditing: true,
      });
    });
  });

  describe.each(['isLoading', 'isFetchingGroupStages'])('when %s', (isFetchingResource) => {
    beforeEach(() => {
      createComponent({ state: { [isFetchingResource]: true } });
    });

    it('renders loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render form content component', () => {
      expect(findFormContent().exists()).toBe(false);
    });
  });
});
