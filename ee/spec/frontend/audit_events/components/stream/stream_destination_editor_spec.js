import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import StreamDestinationEditor from 'ee/audit_events/components/stream/stream_destination_editor.vue';
import StreamDestinationEditorHttpFields from 'ee/audit_events/components/stream/stream_destination_editor_http_fields.vue';
import StreamDestinationEditorAwsFields from 'ee/audit_events/components/stream/stream_destination_editor_aws_fields.vue';
import StreamDestinationEditorGcpFields from 'ee/audit_events/components/stream/stream_destination_editor_gcp_fields.vue';
import StreamEventTypeFilters from 'ee/audit_events/components/stream/stream_event_type_filters.vue';
import StreamNamespaceFilters from 'ee/audit_events/components/stream/stream_namespace_filters.vue';
import StreamDeleteModal from 'ee/audit_events/components/stream/stream_delete_modal.vue';
import {
  DESTINATION_TYPE_AMAZON_S3,
  DESTINATION_TYPE_GCP_LOGGING,
} from 'ee/audit_events/constants';
import {
  newStreamDestination,
  mockConsolidatedAPIExternalDestinations,
  mockConsolidatedAPIAmazonS3Destinations,
  mockConsolidatedAPIGcpLoggingDestinations,
} from '../../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('StreamDestinationEditor', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const propsDefinition = {
    newItem: newStreamDestination,
    httpItem: mockConsolidatedAPIExternalDestinations[0],
    awsItem: {
      ...mockConsolidatedAPIAmazonS3Destinations[0],
      category: DESTINATION_TYPE_AMAZON_S3,
    },
    gcpItem: {
      ...mockConsolidatedAPIGcpLoggingDestinations[0],
      category: DESTINATION_TYPE_GCP_LOGGING,
    },
  };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(StreamDestinationEditor, {
      propsData: {
        ...props,
      },
      provide: {
        ...provide,
      },
    });
  };

  const findDataWarning = () => wrapper.findByTestId('data-warning');
  const findAlertErrors = () => wrapper.findByTestId('alert-errors');
  const findDestinationName = () => wrapper.findByTestId('destination-name');
  const findSubmitButton = () => wrapper.findByTestId('stream-destination-submit-button');
  const findCancelButton = () => wrapper.findByTestId('stream-destination-cancel-button');
  const findDeleteButton = () => wrapper.findByTestId('stream-destination-delete-button');

  const findStreamDestinationEditorHttpFields = () =>
    wrapper.findComponent(StreamDestinationEditorHttpFields);
  const findStreamDestinationEditorAwsFields = () =>
    wrapper.findComponent(StreamDestinationEditorAwsFields);
  const findStreamDestinationEditorGcpFields = () =>
    wrapper.findComponent(StreamDestinationEditorGcpFields);
  const findStreamEventTypeFilters = () => wrapper.findComponent(StreamEventTypeFilters);
  const findStreamNamespaceFilters = () => wrapper.findComponent(StreamNamespaceFilters);
  const findStreamDeleteModal = () => wrapper.findComponent(StreamDeleteModal);

  describe.each`
    groupPath
    ${'group'}
    ${'instance'}
  `('when the view is $groupPath', ({ groupPath }) => {
    describe('when creating new destination', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: propsDefinition.newItem,
          },
          provide: { groupPath },
          stubs: {},
        });
      });

      it('shows data warning message', () => {
        expect(findDataWarning().props('title')).toBe('Destinations receive all audit event data');
        expect(findDataWarning().text()).toBe(
          'This could include sensitive information. Make sure you trust the destination endpoint.',
        );
      });

      it('renders the correct submit button text', () => {
        expect(findSubmitButton().attributes('name')).toBe('Add external stream destination');
        expect(findSubmitButton().text()).toBe('Add');
      });

      it('renders cancel button', () => {
        expect(findCancelButton().exists()).toBe(true);
      });

      it('does not render delete button', () => {
        expect(findDeleteButton().exists()).toBe(false);
      });

      it('does not render delete modal', () => {
        expect(findStreamDeleteModal().exists()).toBe(false);
      });
    });

    describe('when editing a destination', () => {
      describe('when destination category is http', () => {
        beforeEach(() => {
          createComponent({
            props: { item: propsDefinition.httpItem },
            provide: { groupPath },
          });
        });

        it('renders http fields', () => {
          expect(findDestinationName().attributes('value')).toBe('HTTP Destination 1');
          expect(findStreamDestinationEditorHttpFields().props()).toMatchObject({
            value: propsDefinition.httpItem,
            isEditing: true,
            loading: false,
          });
          expect(findStreamEventTypeFilters().props('value')).toBe(
            propsDefinition.httpItem.eventTypeFilters,
          );
        });

        it('renders the correct submit button text', () => {
          expect(findSubmitButton().attributes('name')).toBe('Save external stream destination');
          expect(findSubmitButton().text()).toBe('Save');
        });

        it('renders cancel button', () => {
          expect(findCancelButton().exists()).toBe(true);
        });

        it('renders delete button disabled', () => {
          expect(findDeleteButton().exists()).toBe(true);
        });

        it('passes correct props to delete modal', () => {
          expect(findStreamDeleteModal().props()).toMatchObject({
            item: propsDefinition.httpItem,
            type: 'http',
          });
        });
      });

      describe('when destination category is aws', () => {
        beforeEach(() => {
          createComponent({
            props: { item: propsDefinition.awsItem },
            provide: { groupPath },
          });
        });

        it('renders aws fields', () => {
          expect(findDestinationName().attributes('value')).toBe('AWS Destination 1');
          expect(findStreamDestinationEditorAwsFields().props()).toMatchObject({
            value: propsDefinition.awsItem,
            isEditing: true,
          });
          expect(findStreamEventTypeFilters().props('value')).toBe(
            propsDefinition.awsItem.eventTypeFilters,
          );
        });

        it('passes correct props to delete modal', () => {
          expect(findStreamDeleteModal().props()).toMatchObject({
            item: propsDefinition.awsItem,
            type: DESTINATION_TYPE_AMAZON_S3,
          });
        });
      });

      describe('when destination category is gcp', () => {
        beforeEach(() => {
          createComponent({
            props: { item: propsDefinition.gcpItem },
            provide: { groupPath },
          });
        });

        it('renders gcp fields', () => {
          expect(findDestinationName().attributes('value')).toBe('GCP Destination 1');
          expect(findStreamDestinationEditorGcpFields().props()).toMatchObject({
            value: propsDefinition.gcpItem,
            isEditing: true,
          });
          expect(findStreamEventTypeFilters().props('value')).toBe(
            propsDefinition.gcpItem.eventTypeFilters,
          );
        });

        it('passes correct props to delete modal', () => {
          expect(findStreamDeleteModal().props()).toMatchObject({
            item: propsDefinition.gcpItem,
            type: DESTINATION_TYPE_GCP_LOGGING,
          });
        });
      });
    });

    describe('when deleting a destination', () => {
      beforeEach(() => {
        createComponent({
          props: { item: propsDefinition.httpItem },
          provide: { groupPath },
        });
      });

      it('updates loading state when deleting', async () => {
        await findStreamDeleteModal().vm.$emit('deleting');

        expect(findStreamDestinationEditorHttpFields().props('loading')).toBe(true);
        expect(findSubmitButton().props('loading')).toBe(true);
        expect(findDeleteButton().props('loading')).toBe(true);
      });

      it('resets loading state when delete completes', async () => {
        await findStreamDeleteModal().vm.$emit('deleting');
        await findStreamDeleteModal().vm.$emit('delete');

        expect(wrapper.emitted().deleted).toEqual([
          ['gid://gitlab/AuditEvents::Group::ExternalStreamingDestination/1'],
        ]);

        expect(findStreamDestinationEditorHttpFields().props('loading')).toBe(false);
        expect(findSubmitButton().props('loading')).toBe(false);
        expect(findDeleteButton().props('loading')).toBe(false);
      });

      it('displays error alert when delete fails', async () => {
        const error = new Error('test error');
        await findStreamDeleteModal().vm.$emit('error', error);

        expect(findAlertErrors().text()).toBe(
          'An error occurred when deleting external audit event stream destination. Please try it again.',
        );

        expect(Sentry.captureException).toHaveBeenCalledWith(error);
      });
    });
  });

  describe('for group specific view', () => {
    describe('when editing a destination', () => {
      describe('when destination category is http', () => {
        beforeEach(() => {
          createComponent({
            props: { item: propsDefinition.httpItem },
            provide: { groupPath: 'group' },
          });
        });

        it('renders namespace filters', () => {
          expect(findStreamNamespaceFilters().props('value')).toMatchObject({
            __typename: 'GroupAuditEventNamespaceFilter',
            id: 'gid://gitlab/AuditEvents::Group::NamespaceFilter/1',
            namespace: 'myGroup/project1',
          });
        });
      });
    });
  });

  describe('for instance specific view', () => {
    describe('when editing a destination', () => {
      describe('when destination category is http', () => {
        beforeEach(() => {
          createComponent({
            props: { item: propsDefinition.httpItem },
            provide: { groupPath: 'instance' },
          });
        });

        it('does not render namespace filters', () => {
          expect(findStreamNamespaceFilters().exists()).toBe(false);
        });
      });
    });
  });
});
