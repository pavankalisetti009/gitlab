import {
  buildDefaultPipeLineRule,
  buildDefaultScheduleRule,
  handleBranchTypeSelect,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/rules';
import {
  ALL_PROTECTED_BRANCHES,
  SPECIFIC_BRANCHES,
  PROJECT_DEFAULT_BRANCH,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { SCAN_EXECUTION_RULES_PIPELINE_KEY } from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';

const ruleId = 'rule_0';
jest.mock('lodash/uniqueId', () => jest.fn().mockReturnValue(ruleId));

describe('buildDefaultPipeLineRule', () => {
  it('builds a pipeline rule', () => {
    expect(buildDefaultPipeLineRule()).toEqual({
      branches: ['*'],
      id: ruleId,
      type: 'pipeline',
    });
  });
});

describe('buildDefaultScheduleRule', () => {
  it('builds a schedule rule', () => {
    expect(buildDefaultScheduleRule()).toEqual({
      branches: [],
      cadence: '0 0 * * *',
      id: ruleId,
      type: 'schedule',
    });
  });
});

describe('handleBranchTypeSelect', () => {
  const TARGET_BRANCHES = [ALL_PROTECTED_BRANCHES.value, PROJECT_DEFAULT_BRANCH.value];

  describe('when selecting SPECIFIC_BRANCHES', () => {
    it('returns rule with branches array and removes branch_type for pipeline rules', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branch_type: ALL_PROTECTED_BRANCHES.value,
      };

      const result = handleBranchTypeSelect({
        branchType: SPECIFIC_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        targetBranches: TARGET_BRANCHES,
      });

      expect(result).toEqual({
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['*'],
      });
      expect(result.branch_type).toBeUndefined();
    });

    it('returns rule with empty branches array for non-pipeline rules', () => {
      const rule = {
        type: 'schedule',
        branch_type: ALL_PROTECTED_BRANCHES.value,
      };

      const result = handleBranchTypeSelect({
        branchType: SPECIFIC_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        targetBranches: TARGET_BRANCHES,
      });

      expect(result).toEqual({
        type: 'schedule',
        branches: [],
      });
      expect(result.branch_type).toBeUndefined();
    });

    it('preserves other properties in the rule', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branch_type: ALL_PROTECTED_BRANCHES.value,
        actions: ['scan'],
        branch_exceptions: ['main'],
      };

      const result = handleBranchTypeSelect({
        branchType: SPECIFIC_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        targetBranches: TARGET_BRANCHES,
      });

      expect(result).toEqual({
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['*'],
        actions: ['scan'],
        branch_exceptions: ['main'],
      });
    });
  });

  describe('when selecting a branch type other than SPECIFIC_BRANCHES', () => {
    it('returns rule with branch_type and removes branches property', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['feature/*'],
      };

      const result = handleBranchTypeSelect({
        branchType: ALL_PROTECTED_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        targetBranches: TARGET_BRANCHES,
      });

      expect(result).toEqual({
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branch_type: ALL_PROTECTED_BRANCHES.value,
      });
      expect(result.branches).toBeUndefined();
    });

    it('preserves other properties in the rule', () => {
      const rule = {
        type: 'schedule',
        branches: ['feature/*'],
        actions: ['scan'],
        branch_exceptions: ['main'],
      };

      const result = handleBranchTypeSelect({
        branchType: PROJECT_DEFAULT_BRANCH.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        targetBranches: TARGET_BRANCHES,
      });

      expect(result).toEqual({
        type: 'schedule',
        branch_type: PROJECT_DEFAULT_BRANCH.value,
        actions: ['scan'],
        branch_exceptions: ['main'],
      });
    });
  });

  describe('pipeline_sources handling', () => {
    it('keeps pipeline_sources when selecting a target branch type', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['feature/*'],
        pipeline_sources: ['web', 'api'],
      };

      const result = handleBranchTypeSelect({
        branchType: ALL_PROTECTED_BRANCHES.value, // This is in TARGET_BRANCHES
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        targetBranches: TARGET_BRANCHES,
      });

      expect(result.pipeline_sources).toEqual(['web', 'api']);
    });

    it('removes pipeline_sources when selecting a non-target branch type', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['feature/*'],
        pipeline_sources: ['web', 'api'],
      };

      const result = handleBranchTypeSelect({
        branchType: 'non-target-branch-type', // Not in TARGET_BRANCHES
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        targetBranches: TARGET_BRANCHES,
      });

      expect(result.pipeline_sources).toBeUndefined();
    });

    it('does nothing with pipeline_sources if they do not exist in the rule', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['feature/*'],
      };

      const result = handleBranchTypeSelect({
        branchType: 'non-target-branch-type',
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        targetBranches: TARGET_BRANCHES,
      });

      expect(result.pipeline_sources).toBeUndefined();
    });
  });

  describe('edge cases', () => {
    it('handles empty targetBranches array', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['feature/*'],
        pipeline_sources: ['web', 'api'],
      };

      const result = handleBranchTypeSelect({
        branchType: ALL_PROTECTED_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        targetBranches: [], // Empty array
      });

      // Should remove pipeline_sources since no branch types are targeted
      expect(result.pipeline_sources).toBeUndefined();
    });

    it('handles undefined targetBranches parameter', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['feature/*'],
        pipeline_sources: ['web', 'api'],
      };

      const result = handleBranchTypeSelect({
        branchType: ALL_PROTECTED_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        // No targetBranches parameter
      });

      // Should remove pipeline_sources since targetBranches defaults to empty array
      expect(result.pipeline_sources).toBeUndefined();
    });
  });
});
