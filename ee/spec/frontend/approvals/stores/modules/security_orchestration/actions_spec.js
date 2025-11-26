import * as actions from 'ee/approvals/stores/modules/security_orchestration/actions';
import testAction from 'helpers/vuex_action_helper';
import * as types from 'ee/approvals/stores/modules/security_orchestration/mutation_types';
import getInitialState from 'ee/approvals/stores/modules/security_orchestration/state';
import { gqClient } from 'ee/security_orchestration/utils';
import projectSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_security_policies.query.graphql';
import groupSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_security_policies.query.graphql';

describe('security orchestration actions', () => {
  describe('fetchScanResultPolicies', () => {
    it('uses projectScanResultPoliciesQuery when isGroup is not provided', () => {
      const queryResponse = { data: { namespace: { securityPolicies: { nodes: [] } } } };

      jest.spyOn(gqClient, 'query').mockResolvedValue(queryResponse);

      const action = testAction(
        actions.fetchScanResultPolicies,
        { fullPath: 'namespace/project' },
        getInitialState(),
        [{ type: types.SET_SCAN_RESULT_POLICIES, payload: [] }],
        [],
      );
      expect(gqClient.query).toHaveBeenCalledWith(
        expect.objectContaining({ query: projectSecurityPoliciesQuery }),
      );
      return action;
    });

    it('uses groupScanResultPoliciesQuery when isGroup is true', () => {
      const queryResponse = { data: { namespace: { securityPolicies: { nodes: [] } } } };

      jest.spyOn(gqClient, 'query').mockResolvedValue(queryResponse);

      const action = testAction(
        actions.fetchScanResultPolicies,
        { fullPath: 'namespace/project', isGroup: true },
        getInitialState(),
        [{ type: types.SET_SCAN_RESULT_POLICIES, payload: [] }],
        [],
      );
      expect(gqClient.query).toHaveBeenCalledWith(
        expect.objectContaining({ query: groupSecurityPoliciesQuery }),
      );
      return action;
    });

    it('sets SCAN_RESULT_POLICIES_FAILED when failing', () => {
      jest.spyOn(gqClient, 'query').mockResolvedValue(Promise.reject());

      return testAction(
        actions.fetchScanResultPolicies,
        { fullPath: 'namespace/project' },
        getInitialState(),
        [{ type: types.SCAN_RESULT_POLICIES_FAILED }],
        [],
      );
    });

    it('sets SCAN_RESULT_POLICIES_FAILED when succeeding', () => {
      const policies = [
        {
          name: 'policyName',
          yaml: 'name: policyName',
          actionApprovers: [
            { users: [{ id: 1, name: 'username' }], allGroups: [] },
            { users: [{ id: 2, name: 'username2' }], allGroups: [] },
          ],
          source: { project: { fullPath: 'path/policy' } },
        },
      ];
      const expectedPolicies = [
        {
          name: 'policyName',
          isSelected: false,
          actionApprovers: [
            { users: [{ id: 1, name: 'username' }], allGroups: [] },
            { users: [{ id: 2, name: 'username2' }], allGroups: [] },
          ],
          source: { project: { fullPath: 'path/policy' } },
          type: 'approval_policy',
        },
      ];
      const queryResponse = { data: { namespace: { securityPolicies: { nodes: policies } } } };

      jest.spyOn(gqClient, 'query').mockResolvedValue(queryResponse);

      return testAction(
        actions.fetchScanResultPolicies,
        { fullPath: 'namespace/project' },
        getInitialState(),
        [{ type: types.SET_SCAN_RESULT_POLICIES, payload: expectedPolicies }],
        [],
      );
    });
  });
});
