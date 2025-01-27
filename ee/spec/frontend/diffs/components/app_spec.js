import { shallowMount } from '@vue/test-utils';

import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getMRCodequalityAndSecurityReports from 'ee_else_ce/diffs/components/graphql/get_mr_codequality_and_security_reports.query.graphql';
import { TEST_HOST } from 'spec/test_constants';
import App, { FINDINGS_POLL_INTERVAL } from '~/diffs/components/app.vue';
import store from '~/mr_notes/stores';
import { pinia } from '~/pinia/instance';

import {
  codeQualityNewErrorsHandler,
  SASTParsedHandler,
  SASTParsingAndParsedHandler,
  SASTErrorHandler,
  codeQualityErrorAndParsed,
  requestError,
} from './mocks/queries';

const TEST_ENDPOINT = `${TEST_HOST}/diff/endpoint`;

jest.mock('~/mr_notes/stores', () => jest.requireActual('helpers/mocks/mr_notes/stores'));
Vue.use(VueApollo);

describe('diffs/components/app', () => {
  let fakeApollo;

  const createComponent = (
    props = {},
    baseConfig = {},
    queryHandler = codeQualityNewErrorsHandler,
  ) => {
    store.reset();
    store.getters.isNotesFetched = false;
    store.getters.getNoteableData = {
      current_user: {
        can_create_note: true,
      },
    };
    store.getters['findingsDrawer/activeDrawer'] = {};
    store.getters['diffs/diffFiles'] = [];
    store.getters['diffs/flatBlobsList'] = [];
    store.getters['diffs/isBatchLoading'] = false;
    store.getters['diffs/isBatchLoadingError'] = false;
    store.getters['diffs/whichCollapsedTypes'] = { any: false };

    store.state.diffs.isLoading = false;
    store.state.findingsDrawer = { activeDrawer: false };

    store.state.diffs.isTreeLoaded = true;

    store.dispatch('diffs/setBaseConfig', {
      endpoint: TEST_ENDPOINT,
      endpointMetadata: `${TEST_HOST}/diff/endpointMetadata`,
      endpointBatch: `${TEST_HOST}/diff/endpointBatch`,
      endpointDiffForPath: TEST_ENDPOINT,
      projectPath: 'namespace/project',
      dismissEndpoint: '',
      showSuggestPopover: true,
      mrReviews: {},
      ...baseConfig,
    });

    fakeApollo = createMockApollo([[getMRCodequalityAndSecurityReports, queryHandler]]);

    shallowMount(App, {
      apolloProvider: fakeApollo,
      propsData: {
        endpointCoverage: `${TEST_HOST}/diff/endpointCoverage`,
        endpointCodequality: '',
        sastReportAvailable: false,
        currentUser: {},
        changesEmptyStateIllustration: '',
        ...props,
      },
      mocks: {
        $store: store,
      },
      pinia,
    });
  };

  describe('EE codequality diff', () => {
    it('polls Code Quality data via GraphQL and not via REST when codequalityReportAvailable is true', async () => {
      createComponent(
        { shouldShow: true, codequalityReportAvailable: true },
        {},
        codeQualityErrorAndParsed,
      );
      await waitForPromises();
      expect(codeQualityErrorAndParsed).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(codeQualityErrorAndParsed).toHaveBeenCalledTimes(2);
    });

    it('does not poll Code Quality data via GraphQL when codequalityReportAvailable is false', async () => {
      createComponent(
        { shouldShow: true, codequalityReportAvailable: false },
        {},
        codeQualityErrorAndParsed,
      );
      await waitForPromises();
      expect(codeQualityErrorAndParsed).toHaveBeenCalledTimes(0);
    });

    it('stops polling when newErrors in response are defined', async () => {
      createComponent(
        {
          shouldShow: true,
          codequalityReportAvailable: true,
        },
        {},
      );

      await waitForPromises();

      expect(codeQualityNewErrorsHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(codeQualityNewErrorsHandler).toHaveBeenCalledTimes(1);
    });

    it('does not fetch code quality data when endpoint is blank', () => {
      createComponent({ shouldShow: false, endpointCodequality: '' }, {});
      expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
    });
  });

  describe('EE SAST diff', () => {
    it('polls SAST data when sastReportAvailable is true', async () => {
      createComponent(
        { shouldShow: true, sastReportAvailable: true },
        {},
        SASTParsingAndParsedHandler,
      );
      await waitForPromises();

      expect(SASTParsingAndParsedHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(SASTParsingAndParsedHandler).toHaveBeenCalledTimes(2);
    });

    it('stops polling when sastReport status is PARSED', async () => {
      createComponent(
        {
          shouldShow: true,
          sastReportAvailable: true,
        },
        {},
        SASTParsedHandler,
      );

      await waitForPromises();

      expect(SASTParsedHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(SASTParsedHandler).toHaveBeenCalledTimes(1);
    });

    it('stops polling on request error', async () => {
      createComponent({ shouldShow: true, sastReportAvailable: true }, {}, requestError);
      await waitForPromises();

      expect(requestError).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(requestError).toHaveBeenCalledTimes(1);
    });

    it('stops polling on response status error', async () => {
      createComponent({ shouldShow: true, sastReportAvailable: true }, {}, SASTErrorHandler);
      await waitForPromises();

      expect(SASTErrorHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(SASTErrorHandler).toHaveBeenCalledTimes(1);
    });

    it('does not fetch SAST data when sastReportAvailable is false', () => {
      createComponent({ shouldShow: false }, {});
      expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
    });
  });
});
