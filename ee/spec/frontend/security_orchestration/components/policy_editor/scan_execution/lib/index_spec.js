import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';
import {
  DEFAULT_SCAN_EXECUTION_POLICY,
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
  DEFAULT_SCAN_EXECUTION_POLICY_OPTIMIZED,
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_OPTIMIZED,
  OPTIMIZED_RULES,
  getPolicyYaml,
  hasOptimizedRules,
  hasUniqueScans,
  hasOnlyAllowedScans,
  hasSimpleScans,
  getConfiguration,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  SELECTION_CONFIG_CUSTOM,
  SELECTION_CONFIG_DEFAULT,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';

describe('getPolicyYaml', () => {
  let originalGon;

  beforeEach(() => {
    originalGon = window.gon;
    window.gon = { features: {} };
  });

  afterEach(() => {
    window.gon = originalGon;
  });

  describe('with feature flag disabled', () => {
    beforeEach(() => {
      window.gon.features = { flexibleScanExecutionPolicy: false };
    });

    it.each`
      namespaceType              | expected
      ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_EXECUTION_POLICY}
      ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE}
    `('returns the standard yaml for $namespaceType namespace', ({ namespaceType, expected }) => {
      expect(getPolicyYaml({ isGroup: isGroup(namespaceType) })).toEqual(expected);
    });
  });

  describe('with feature flag enabled', () => {
    beforeEach(() => {
      window.gon.features = { flexibleScanExecutionPolicy: true };
    });

    it.each`
      namespaceType              | expected
      ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_EXECUTION_POLICY_OPTIMIZED}
      ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_OPTIMIZED}
    `('returns the optimized yaml for $namespaceType namespace', ({ namespaceType, expected }) => {
      expect(getPolicyYaml({ isGroup: isGroup(namespaceType) })).toEqual(expected);
    });
  });
});

describe('hasOptimizedRules', () => {
  it('returns true when the rules match the optimized ones', () => {
    expect(hasOptimizedRules(OPTIMIZED_RULES)).toBe(true);
  });

  it('returns true when the rules match the optimized ones ignoring ids', () => {
    const OPTIMIZED_RULES_WITH_IDS = OPTIMIZED_RULES.map((rule, index) => ({
      ...rule,
      id: index.toString(),
    }));
    expect(hasOptimizedRules(OPTIMIZED_RULES_WITH_IDS)).toBe(true);
  });

  it('returns false when the rules include extra rules', () => {
    expect(
      hasOptimizedRules([...OPTIMIZED_RULES, { type: 'pipeline', branch_type: 'protected' }]),
    ).toBe(false);
  });

  it('returns false when the rules do not include the optimized rules', () => {
    expect(hasOptimizedRules([{ type: 'pipeline', branch_type: 'protected' }])).toBe(false);
  });

  it('returns false when the rules do not include the optimized rules ignoring rule id', () => {
    expect(hasOptimizedRules([{ type: 'pipeline', branch_type: 'protected', id: '1' }])).toBe(
      false,
    );
  });

  it('returns false for empty rules', () => {
    expect(hasOptimizedRules([])).toBe(false);
  });
});

describe('hasUniqueScans', () => {
  it('returns true when all actions have unique scan values', () => {
    const actions = [{ scan: 'sast_iac' }, { scan: 'sast' }, { scan: 'secret_detection' }];

    expect(hasUniqueScans(actions)).toBe(true);
  });

  it('returns false when actions contain duplicate scan values', () => {
    const actions = [
      { scan: 'secret_detection' },
      { scan: 'sast' },
      { scan: 'secret_detection' }, // Duplicate scan value
    ];

    expect(hasUniqueScans(actions)).toBe(false);
  });

  it('returns true for an empty actions array', () => {
    expect(hasUniqueScans([])).toBe(true);
  });

  it('handles actions with missing scan property', () => {
    const actions = [
      { scan: 'secret_detection' },
      { otherProp: 'value' }, // Missing scan property
      { scan: 'sast' },
    ];

    // This test assumes that actions with missing scan properties are considered unique
    // Adjust the expectation based on the actual intended behavior
    expect(hasUniqueScans(actions)).toBe(true);
  });
});

describe('hasOnlyAllowedScans', () => {
  it('returns true when no actions have DAST scan type', () => {
    const actions = [
      { scan: 'sast' },
      { scan: 'secret_detection' },
      { scan: 'container_scanning' },
    ];

    expect(hasOnlyAllowedScans(actions)).toBe(true);
  });

  it('returns false when at least one action has DAST scan type', () => {
    const actions = [{ scan: 'sast' }, { scan: REPORT_TYPE_DAST }, { scan: 'secret_detection' }];

    expect(hasOnlyAllowedScans(actions)).toBe(false);
  });

  it('returns true for an empty actions array', () => {
    expect(hasOnlyAllowedScans([])).toBe(true);
  });
});

describe('hasSimpleScans', () => {
  it('returns true when all actions have only template: latest besides id and scan', () => {
    const actions = [{ id: 1, scan: 'sast', template: 'latest' }];

    expect(hasSimpleScans(actions)).toBe(true);
  });

  it('returns false when any action has additional properties', () => {
    const actions = [{ id: 1, scan: REPORT_TYPE_DAST, template: 'latest', runners: ['value'] }];

    expect(hasSimpleScans(actions)).toBe(false);
  });

  it('returns false when any action has different template value', () => {
    const actions = [{ id: 1, scan: 'secret_detection', template: 'default' }];

    expect(hasSimpleScans(actions)).toBe(false);
  });

  it('returns false when any action is missing template property', () => {
    const actions = [{ id: 1, scan: 'sast' }];

    expect(hasSimpleScans(actions)).toBe(false);
  });

  it('returns true for an empty actions array', () => {
    expect(hasSimpleScans([])).toBe(true);
  });
});

describe('getConfiguration', () => {
  it('returns "default" when all conditions are met', () => {
    const policy = { actions: [{ scan: 'sast', template: 'latest' }], rules: OPTIMIZED_RULES };
    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_DEFAULT);
  });

  it('returns "custom" when hasOptimizedRules is false', () => {
    const policy = { actions: [{ scan: 'sast', template: 'latest' }], rules: [{}] };

    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_CUSTOM);
  });

  it('returns "custom" when hasOnlyAllowedScans is false', () => {
    const policy = {
      actions: [{ scan: REPORT_TYPE_DAST, template: 'latest' }],
      rules: OPTIMIZED_RULES,
    };

    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_CUSTOM);
  });

  it('returns "custom" when hasUniqueScans is false', () => {
    const policy = {
      actions: [
        { scan: 'sast', template: 'latest' },
        { scan: 'sast', template: 'latest' },
      ],
      rules: OPTIMIZED_RULES,
    };

    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_CUSTOM);
  });

  it('returns "custom" when hasSimpleScans is false', () => {
    const policy = {
      actions: [{ scan: REPORT_TYPE_DAST, template: 'latest' }],
      rules: OPTIMIZED_RULES,
    };

    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_CUSTOM);
  });

  it('handles policy with no actions and no rules', () => {
    const policy = { actions: [], rules: [] };

    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_CUSTOM);
  });
});
