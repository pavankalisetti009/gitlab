import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import CsvExportButton from 'ee/security_dashboard/components/shared/csv_export_button.vue';
import { TEST_HOST } from 'helpers/test_constants';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import {
  HTTP_STATUS_ACCEPTED,
  HTTP_STATUS_NOT_FOUND,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';

jest.mock('~/alert');
jest.mock('~/lib/utils/downloader');

const vulnerabilitiesExportEndpoint = `${TEST_HOST}/vulnerability_findings.csv`;

describe('CsvExportButton', () => {
  let wrapper;
  let mock;

  const findButton = () => wrapper.findComponent(GlButton);

  const createComponent = () => {
    wrapper = shallowMount(CsvExportButton, {
      provide: {
        vulnerabilitiesExportEndpoint,
      },
    });
  };

  const mockSyncExportRequest = (download, status = 'finished') => {
    mock
      .onPost(vulnerabilitiesExportEndpoint)
      .reply(HTTP_STATUS_ACCEPTED, { _links: { self: 'status/url' } });

    mock.onGet('status/url').reply(HTTP_STATUS_OK, { _links: { download }, status });
  };

  const mockAsyncExportRequest = (status = HTTP_STATUS_ACCEPTED) => {
    mock.onPost(vulnerabilitiesExportEndpoint, { send_email: true }).reply(status);
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('asynchronous export', () => {
    describe.each`
      entity
      ${'group'}
      ${'project'}
    `('CsvExportButton for $entity dashboard', ({ entity }) => {
      beforeEach(() => {
        createComponent();
      });

      it(`sends async export request and shows success alert for ${entity}`, async () => {
        mockAsyncExportRequest();

        findButton().vm.$emit('click');
        await axios.waitForAll();

        expect(mock.history.post[0].data).toBe(JSON.stringify({ send_email: true }));
        expect(createAlert).toHaveBeenCalledWith({
          message: 'The report is being generated and will be sent to your email.',
          variant: 'info',
          dismissible: true,
        });
      });

      it(`shows error alert when async export fails for ${entity}`, async () => {
        mockAsyncExportRequest(HTTP_STATUS_NOT_FOUND);

        findButton().vm.$emit('click');
        await axios.waitForAll();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was an error while generating the report.',
          variant: 'danger',
          dismissible: true,
        });
      });
    });
  });

  describe('button loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('toggles loading and icon correctly', async () => {
      const url = 'download/url';
      mockSyncExportRequest(url);

      findButton().vm.$emit('click');
      await nextTick();

      expect(findButton().props()).toMatchObject({
        loading: true,
        icon: '',
      });

      await axios.waitForAll();

      expect(findButton().props()).toMatchObject({
        loading: false,
        icon: 'export',
      });
    });
  });

  describe('tooltip', () => {
    describe.each`
      entity
      ${'group'}
      ${'project'}
    `('when async export is enabled for $entity', ({ entity }) => {
      it(`shows "Send as CSV to email" for ${entity}`, () => {
        createComponent();

        expect(findButton().attributes('title')).toBe('Send as CSV to email');
      });
    });
  });

  describe('button disabled state', () => {
    it('enables the button when vulnerabilitiesExportEndpoint is provided', () => {
      createComponent();

      expect(findButton().props('disabled')).toBe(false);
    });

    it('disables the button when vulnerabilitiesExportEndpoint is not provided', () => {
      wrapper = shallowMount(CsvExportButton, {
        provide: {
          vulnerabilitiesExportEndpoint: null,
        },
      });

      expect(findButton().props('disabled')).toBe(true);
    });
  });
});
