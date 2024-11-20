/* eslint-disable @gitlab/require-i18n-strings */
export const resolvers = {
  Query: {
    mockControls: () => ({
      controls: [
        {
          id: 'scanner_sast_running',
          name: 'SAST Running',
          expression: {
            field: 'scanner_sast_running',
            operator: '=',
            value: true,
          },
        },
        {
          id: 'minimum_approvals_required_2',
          name: 'At least two approvals',
          expression: {
            field: 'minimum_approvals_required',
            operator: '=',
            value: 2,
          },
        },
        {
          id: 'minimum_approvals_required_3',
          name: 'At least three approvals',
          value: {
            field: 'minimum_approvals_required',
            operator: '=',
            value: 3,
          },
        },
        {
          id: 'merge_request_prevent_author_approval',
          name: 'Author approved merge request',
          expression: {
            field: 'merge_request_prevent_author_approval',
            operator: '=',
            value: true,
          },
        },
        {
          id: 'merge_request_prevent_committers_approval',
          name: 'Committers approved merge request',
          expression: {
            field: 'merge_request_prevent_committers_approval',
            operator: '=',
            value: true,
          },
        },
        {
          id: 'project_visibility_not_internal',
          name: 'Internal visibility is forbidden',
          expression: {
            field: 'project_visibility',
            operator: '=',
            value: 'internal',
          },
        },
        {
          id: 'default_branch_protected',
          name: 'Default branch protected',
          expression: {
            field: 'default_branch_protected',
            operator: '=',
            value: true,
          },
        },
      ],
    }),
  },
  ComplianceRequirement: {
    controlExpression: () => `{
              "operator": "AND",
              "conditions": [
                {
                  "id": "minimum_approvals_required_2",
                  "field": "minimum_approvals_required",
                  "operator": "=",
                  "value": "2"
                },
                {
                  "id": "minimum_approvals_required_3",
                  "field": "minimum_approvals_required",
                  "operator": "=",
                  "value": "3"
                }
              ]
            }`,
  },
};
