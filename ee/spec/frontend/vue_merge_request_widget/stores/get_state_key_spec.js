import getStateKey from 'ee/vue_merge_request_widget/stores/get_state_key';
import {
  DETAILED_MERGE_STATUS,
  MWCP_MERGE_STRATEGY,
  MTWCP_MERGE_STRATEGY,
  MT_MERGE_STRATEGY,
} from '~/vue_merge_request_widget/constants';

describe('EE getStateKey', () => {
  const createContext = (detailedMergeStatus, preferredAutoMergeStrategy, autoMergeEnabled) => ({
    canMerge: true,
    commitsCount: 2,
    detailedMergeStatus,
    preferredAutoMergeStrategy,
    autoMergeEnabled,
  });

  beforeEach(() => {
    window.gon = { features: {} };
  });

  afterEach(() => {
    delete window.gon;
  });

  describe('when auto merge is not enabled', () => {
    describe('with merge train strategy', () => {
      it.each`
        featureFlagEnabled | detailedMergeStatus                   | expectedState
        ${true}            | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
        ${true}            | ${DETAILED_MERGE_STATUS.NOT_APPROVED} | ${'readyToMerge'}
        ${false}           | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
        ${false}           | ${DETAILED_MERGE_STATUS.NOT_APPROVED} | ${null}
      `(
        'returns $expectedState when feature flag is $featureFlagEnabled and status is $detailedMergeStatus',
        ({ featureFlagEnabled, detailedMergeStatus, expectedState }) => {
          window.gon.features.allowMergeTrainRetryMerge = featureFlagEnabled;
          const context = createContext(detailedMergeStatus, MT_MERGE_STRATEGY, false);
          const bound = getStateKey.bind(context);

          expect(bound()).toBe(expectedState);
        },
      );

      it('returns readyToMerge when feature flag is undefined', () => {
        // window.gon.features.allowMergeTrainRetryMerge is undefined
        const context = createContext(DETAILED_MERGE_STATUS.MERGEABLE, MT_MERGE_STRATEGY, false);
        const bound = getStateKey.bind(context);

        expect(bound()).toBe('readyToMerge');
      });

      it('returns readyToMerge when gon is undefined', () => {
        delete window.gon;
        const context = createContext(DETAILED_MERGE_STATUS.MERGEABLE, MT_MERGE_STRATEGY, false);
        const bound = getStateKey.bind(context);

        expect(bound()).toBe('readyToMerge');
      });
    });

    describe('with other auto merge strategies', () => {
      it.each`
        strategy                | detailedMergeStatus                   | expectedState
        ${MWCP_MERGE_STRATEGY}  | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
        ${MWCP_MERGE_STRATEGY}  | ${DETAILED_MERGE_STATUS.NOT_APPROVED} | ${'readyToMerge'}
        ${MTWCP_MERGE_STRATEGY} | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
        ${MTWCP_MERGE_STRATEGY} | ${DETAILED_MERGE_STATUS.NOT_APPROVED} | ${'readyToMerge'}
      `(
        'returns $expectedState for $strategy regardless of feature flag state',
        ({ strategy, detailedMergeStatus, expectedState }) => {
          window.gon.features.allowMergeTrainRetryMerge = false;
          const context = createContext(detailedMergeStatus, strategy, false);
          const bound = getStateKey.bind(context);

          expect(bound()).toBe(expectedState);
        },
      );
    });
  });

  describe('when auto merge is enabled', () => {
    it.each`
      strategy               | featureFlagEnabled | detailedMergeStatus                   | expectedState
      ${MT_MERGE_STRATEGY}   | ${true}            | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
      ${MT_MERGE_STRATEGY}   | ${true}            | ${DETAILED_MERGE_STATUS.NOT_APPROVED} | ${null}
      ${MT_MERGE_STRATEGY}   | ${false}           | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
      ${MWCP_MERGE_STRATEGY} | ${true}            | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
      ${MWCP_MERGE_STRATEGY} | ${false}           | ${DETAILED_MERGE_STATUS.MERGEABLE}    | ${'readyToMerge'}
    `(
      'returns $expectedState for $strategy when auto merge is enabled (feature flag: $featureFlagEnabled)',
      ({ strategy, featureFlagEnabled, detailedMergeStatus, expectedState }) => {
        window.gon.features.allowMergeTrainRetryMerge = featureFlagEnabled;
        const context = createContext(detailedMergeStatus, strategy, true);
        const bound = getStateKey.bind(context);

        expect(bound()).toBe(expectedState);
      },
    );
  });
});
