import { GlLoadingIcon, GlAlert } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_NOT_FOUND } from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';
import ValueStreamForm from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form.vue';
import ValueStreamFormContent from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  endpoints,
  valueStreams,
  customizableStagesAndEvents,
} from 'ee_jest/analytics/cycle_analytics/mock_data';
import { defaultStages } from '../mock_data';

const [valueStream] = valueStreams;

describe('ValueStreamForm', () => {
  let axiosMock;
  let wrapper = null;

  const createWrapper = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ValueStreamForm, {
      provide: {
        namespaceFullPath: 'fake/path',
        valueStream: undefined,
        defaultStages,
        ...provide,
      },
      propsData: props,
    });
  };

  const findFormContent = () => wrapper.findComponent(ValueStreamFormContent);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findErrorAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
  });

  describe('new value stream', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('does not send any requests', () => {
      expect(axiosMock.history.get).toHaveLength(0);
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('does not render an alert', () => {
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('renders form content component', () => {
      expect(findFormContent().props()).toMatchObject({
        initialData: { name: '', stages: [] },
        isEditing: false,
      });
    });
  });

  describe('edit value stream', () => {
    describe('when loading', () => {
      beforeEach(() => {
        axiosMock
          .onGet(endpoints.baseStagesEndpoint)
          .reply(HTTP_STATUS_OK, customizableStagesAndEvents);

        createWrapper({
          provide: { valueStream },
          props: { isEditing: true },
        });
      });

      it('sends a request to fetch the stages', () => {
        expect(axiosMock.history.get).toHaveLength(1);
        expect(axiosMock.history.get[0].url).toEqual(
          '/fake/path/-/analytics/value_stream_analytics/value_streams/1/stages',
        );
      });

      it('renders loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('does not render an alert', () => {
        expect(findErrorAlert().exists()).toBe(false);
      });

      it('does not render form content component', () => {
        expect(findFormContent().exists()).toBe(false);
      });

      describe('when loaded', () => {
        beforeEach(() => {
          return waitForPromises();
        });

        it('does not render loading icon', () => {
          expect(findLoadingIcon().exists()).toBe(false);
        });

        it('does not render an alert', () => {
          expect(findErrorAlert().exists()).toBe(false);
        });

        it('renders form content component', () => {
          expect(findFormContent().props()).toMatchObject({
            isEditing: true,
            initialData: {
              id: valueStream.id,
              name: valueStream.name,
              stages: expect.any(Array),
            },
          });

          expect(findFormContent().props().initialData.stages).toHaveLength(
            customizableStagesAndEvents.stages.length,
          );
        });
      });
    });

    describe('when an error is thrown', () => {
      beforeEach(() => {
        axiosMock.onGet(endpoints.baseStagesEndpoint).reply(HTTP_STATUS_NOT_FOUND);

        createWrapper({
          provide: { valueStream },
          props: { isEditing: true },
        });

        return waitForPromises();
      });

      it('does not render loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('renders an alert', () => {
        expect(findErrorAlert().text()).toBe(
          'There was an error fetching value stream analytics stages.',
        );
      });

      it('does not render form content component', () => {
        expect(findFormContent().exists()).toBe(false);
      });
    });
  });
});
