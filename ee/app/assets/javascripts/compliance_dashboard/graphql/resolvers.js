/* eslint-disable @gitlab/require-i18n-strings */
export const resolvers = {
  ComplianceFramework: {
    mockRequirements: () => {
      return {
        __typename: 'LocalRequirements',
        nodes: [
          {
            __typename: 'ComplianceRequirement',
            id: 'gid://gitlab/Requirement/1',
            name: 'SOC2',
            description: 'Controls for SOC2',
            requirementType: 'internal',
            controlExpression: {
              __typename: 'ControlExpressionConnection',
              nodes: [
                {
                  id: 'gid://gitlab/Control/1',
                  name: 'At least one non-author approval',
                  __typename: 'ControlExpression',
                },
              ],
            },
          },
          {
            __typename: 'ComplianceRequirement',
            id: 'gid://gitlab/Requirement/2',
            name: 'GitLab',
            description: 'Controls used by GitLab',
            requirementType: 'internal',
            controlExpression: {
              __typename: 'ControlExpressionConnection',
              nodes: [
                {
                  id: 'gid://gitlab/Control/2',
                  name: 'At least two approvals',
                  __typename: 'ControlExpression',
                },
                {
                  id: 'gid://gitlab/Control/3',
                  name: 'Prevent commiters as approvers',
                  __typename: 'ControlExpression',
                },
                {
                  id: 'gid://gitlab/Control/4',
                  name: 'Prevent auhors as approvers',
                  __typename: 'ControlExpression',
                },
              ],
            },
          },
        ],
      };
    },
  },
};
