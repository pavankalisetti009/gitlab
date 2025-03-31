import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import CsvExportButton from 'ee/security_dashboard/components/shared/csv_export_button.vue';
import { TEST_HOST } from 'helpers/test_constants';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { formatDate } from '~/lib/utils/datetime_utility';
import downloader from '~/lib/utils/downloader';
import {
  HTTP_STATUS_ACCEPTED,
  HTTP_STATUS_NOT_FOUND,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';
import { DASHBOARD_TYPE_GROUP, DASHBOARD_TYPE_PROJECT } from 'ee/security_dashboard/constants';

jest.mock('~/alert');
jest.mock('~/lib/utils/downloader');

const mockReportDate = formatDate(new Date(), 'isoDateTime');
const vulnerabilitiesExportEndpoint = `${TEST_HOST}/vulnerability_findings.csv`;

const groupProps = {
  entity: 'group',
  dashboardType: DASHBOARD_TYPE_GROUP,
  glFeatures: {
    asynchronousVulnerabilityExportDeliveryForGroups: true,
  },
};

const projectProps = {
  entity: 'project',
  dashboardType: DASHBOARD_TYPE_PROJECT,
  glFeatures: {
    asynchronousVulnerabilityExportDeliveryForProjects: true,
  },
};

describe('CsvExportButton', () => {
  let wrapper;
  let mock;

  const findButton = () => wrapper.findComponent(GlButton);

  const createComponent = ({ glFeatures = {}, dashboardType = DASHBOARD_TYPE_PROJECT } = {}) => {
    wrapper = shallowMount(CsvExportButton, {
      provide: {
        vulnerabilitiesExportEndpoint,
        glFeatures,
        dashboardType,
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

  describe('synchronous export (feature flag disabled)', () => {
    beforeEach(() => {
      createComponent({ glFeatures: {} });
    });

    it('renders button with correct text', () => {
      expect(findButton().text()).toBe('Export');
    });

    it('downloads CSV on successful export job completion', async () => {
      const url = 'download/url';
      mockSyncExportRequest(url);

      findButton().vm.$emit('click');
      await axios.waitForAll();

      expect(downloader).toHaveBeenCalledWith({
        fileName: `csv-export-${mockReportDate}.csv`,
        url,
      });
    });

    it('shows error alert on export failure', async () => {
      mock.onPost(vulnerabilitiesExportEndpoint).reply(HTTP_STATUS_NOT_FOUND);

      findButton().vm.$emit('click');
      await axios.waitForAll();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error while generating the report.',
        variant: 'danger',
        dismissible: true,
      });
    });

    it('shows error alert on failed export status', async () => {
      mockSyncExportRequest('', 'failed');

      findButton().vm.$emit('click');
      await axios.waitForAll();

      expect(downloader).not.toHaveBeenCalled();
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error while generating the report.',
        variant: 'danger',
        dismissible: true,
      });
    });
  });

  describe('asynchronous export (feature flag enabled)', () => {
    describe.each`
      props
      ${groupProps}
      ${projectProps}
    `('CsvExportButton for $props.entity dashboard', ({ props }) => {
      beforeEach(() => {
        createComponent({
          glFeatures: props.glFeatures,
          dashboardType: props.dashboardType,
        });
      });

      it(`sends async export request and shows success alert for ${props.entity}`, async () => {
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

      it(`shows error alert when async export fails for ${props.entity}`, async () => {
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
      createComponent({ glFeatures: {} });
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
    it('shows "Export as CSV" when async export is disabled', () => {
      createComponent({ glFeatures: {} });

      expect(findButton().attributes('title')).toBe('Export as CSV');
    });

    describe.each`
      props
      ${groupProps}
      ${projectProps}
    `('when async export is enabled for $props.entity', ({ props }) => {
      it(`shows "Send as CSV to email" for ${props.entity}`, () => {
        createComponent({ glFeatures: props.glFeatures, dashboardType: props.dashboardType });

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
          glFeatures: {},
          dashboardType: DASHBOARD_TYPE_PROJECT,
        },
      });

      expect(findButton().props('disabled')).toBe(true);
    });
  });
});
