export const resolvers = {
  ComplianceRequirement: {
    controlExpression: () => `{
              "operator": "AND",
              "conditions": [
                {
                  "id": "minimum_approvals_required_2",
                  "field": "minimum_approvals_required",
                  "operator": "=",
                  "value": 2
                },
                {
                 "id": "scanner_sast_running",
                  "field": "scanner_sast_running",
                  "operator": "=",
                  "value": true
                } 
              ]
            }`,
  },
};
