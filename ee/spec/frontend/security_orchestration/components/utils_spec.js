import {
  isPolicyInherited,
  policyHasNamespace,
  isDefaultMode,
  policyScopeHasExcludingProjects,
  policyScopeHasIncludingProjects,
  policyScopeProjectsKey,
  policyScopeHasComplianceFrameworks,
  policyScopeProjectLength,
  policyScopeComplianceFrameworks,
  policyScopeProjects,
  policyScopeGroups,
  policyScopeHasGroups,
  policyExcludingProjects,
  isProject,
  isGroup,
  isScanningReport,
} from 'ee/security_orchestration/components/utils';
import {
  EXCLUDING,
  INCLUDING,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe(isPolicyInherited, () => {
  it.each`
    input                   | output
    ${undefined}            | ${false}
    ${{}}                   | ${false}
    ${{ inherited: false }} | ${false}
    ${{ inherited: true }}  | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isPolicyInherited(input)).toBe(output);
  });
});

describe(policyHasNamespace, () => {
  it.each`
    input                              | output
    ${undefined}                       | ${false}
    ${{}}                              | ${false}
    ${{ namespace: undefined }}        | ${false}
    ${{ namespace: {} }}               | ${true}
    ${{ namespace: { name: 'name' } }} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyHasNamespace(input)).toBe(output);
  });
});

describe(isDefaultMode, () => {
  it.each`
    input                                      | output
    ${undefined}                               | ${true}
    ${{}}                                      | ${true}
    ${null}                                    | ${true}
    ${{ complianceFrameworks: { nodes: [] } }} | ${false}
    ${{ excludingProjects: { nodes: [] } }}    | ${false}
    ${{ includingProjects: { nodes: [] } }}    | ${false}
    ${{
  complianceFrameworks: { nodes: [] },
  excludingProjects: { nodes: [] },
  includingProjects: { nodes: [] },
}} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isDefaultMode(input)).toBe(output);
  });
});

describe(policyScopeHasExcludingProjects, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${false}
    ${{}}                                                       | ${false}
    ${null}                                                     | ${false}
    ${{ complianceFrameworks: [] }}                             | ${false}
    ${{ includingProjects: { nodes: [] } }}                     | ${false}
    ${{ excludingProjects: { nodes: [] } }}                     | ${false}
    ${{ excludingProjects: { nodes: [{}] } }}                   | ${true}
    ${{ excludingProjects: { nodes: [undefined] } }}            | ${false}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeHasExcludingProjects(input)).toBe(output);
  });
});

describe(policyScopeHasIncludingProjects, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${false}
    ${{}}                                                       | ${false}
    ${null}                                                     | ${false}
    ${{ complianceFrameworks: [] }}                             | ${false}
    ${{ includingProjects: { nodes: [] } }}                     | ${false}
    ${{ excludingProjects: { nodes: [] } }}                     | ${false}
    ${{ excludingProjects: { nodes: [{}] } }}                   | ${false}
    ${{ excludingProjects: { nodes: [undefined] } }}            | ${false}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${false}
    ${{ includingProjects: { nodes: [undefined] } }}            | ${false}
    ${{ includingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeHasIncludingProjects(input)).toBe(output);
  });
});

describe(policyScopeProjectsKey, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${EXCLUDING}
    ${{}}                                                       | ${EXCLUDING}
    ${null}                                                     | ${EXCLUDING}
    ${{ complianceFrameworks: { nodes: [] } }}                  | ${EXCLUDING}
    ${{ includingProjects: { nodes: [] } }}                     | ${EXCLUDING}
    ${{ excludingProjects: { nodes: [] } }}                     | ${EXCLUDING}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${EXCLUDING}
    ${{ includingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${INCLUDING}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeProjectsKey(input)).toBe(output);
  });
});

describe(policyScopeHasComplianceFrameworks, () => {
  it.each`
    input                                               | output
    ${undefined}                                        | ${false}
    ${{}}                                               | ${false}
    ${null}                                             | ${false}
    ${{ complianceFrameworks: [] }}                     | ${false}
    ${{ complianceFrameworks: { nodes: [{}] } }}        | ${true}
    ${{ complianceFrameworks: { nodes: undefined } }}   | ${false}
    ${{ complianceFrameworks: { nodes: [{ id: 1 }] } }} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeHasComplianceFrameworks(input)).toBe(output);
  });
});

describe(policyScopeHasGroups, () => {
  it.each`
    input                                                     | output
    ${undefined}                                              | ${false}
    ${{}}                                                     | ${false}
    ${null}                                                   | ${false}
    ${{ includingGroups: { nodes: [] } }}                     | ${false}
    ${{ includingGroups: { nodes: [{}] } }}                   | ${true}
    ${{ includingGroups: { nodes: [undefined] } }}            | ${false}
    ${{ includingGroups: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${true}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeHasGroups(input)).toBe(output);
  });
});

describe(policyScopeProjectLength, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${0}
    ${{}}                                                       | ${0}
    ${null}                                                     | ${0}
    ${{ complianceFrameworks: { nodes: [] } }}                  | ${0}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${2}
    ${{ includingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${2}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeProjectLength(input)).toBe(output);
  });
});

describe(policyScopeComplianceFrameworks, () => {
  it.each`
    input                                                          | output
    ${undefined}                                                   | ${[]}
    ${{}}                                                          | ${[]}
    ${null}                                                        | ${[]}
    ${{ complianceFrameworks: { nodes: [] } }}                     | ${[]}
    ${{ includingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }}    | ${[]}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }}    | ${[]}
    ${{ complianceFrameworks: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${[{ id: 1 }, { id: 2 }]}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeComplianceFrameworks(input)).toEqual(output);
  });
});

describe(policyScopeProjects, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${{ pageInfo: {}, projects: [] }}
    ${{}}                                                       | ${{ pageInfo: {}, projects: [] }}
    ${null}                                                     | ${{ pageInfo: {}, projects: [] }}
    ${{ compliance_frameworks: [] }}                            | ${{ pageInfo: {}, projects: [] }}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${{ pageInfo: {}, projects: [{ id: 1 }, { id: 2 }] }}
    ${{ includingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${{ pageInfo: {}, projects: [{ id: 1 }, { id: 2 }] }}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeProjects(input)).toEqual(output);
  });
});

describe(policyScopeGroups, () => {
  it.each`
    input                                                     | output
    ${undefined}                                              | ${[]}
    ${{}}                                                     | ${[]}
    ${null}                                                   | ${[]}
    ${{ excludingGroups: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${[]}
    ${{ includingGroups: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${[{ id: 1 }, { id: 2 }]}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyScopeGroups(input)).toEqual(output);
  });
});

describe(policyExcludingProjects, () => {
  it.each`
    input                                                       | output
    ${undefined}                                                | ${[]}
    ${{}}                                                       | ${[]}
    ${null}                                                     | ${[]}
    ${{ excludingProjects: { nodes: [undefined] } }}            | ${[]}
    ${{ excludingProjects: { nodes: [{}] } }}                   | ${[{}]}
    ${{ excludingProjects: { nodes: [{ id: 1 }, { id: 2 }] } }} | ${[{ id: 1 }, { id: 2 }]}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(policyExcludingProjects(input)).toEqual(output);
  });
});

describe(isProject, () => {
  it.each`
    input                      | output
    ${NAMESPACE_TYPES.PROJECT} | ${true}
    ${NAMESPACE_TYPES.GROUP}   | ${false}
    ${null}                    | ${false}
    ${undefined}               | ${false}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isProject(input)).toEqual(output);
  });
});

describe(isGroup, () => {
  it.each`
    input                      | output
    ${NAMESPACE_TYPES.PROJECT} | ${false}
    ${NAMESPACE_TYPES.GROUP}   | ${true}
    ${null}                    | ${false}
    ${undefined}               | ${false}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isGroup(input)).toEqual(output);
  });
});

describe(isScanningReport, () => {
  it.each`
    input                    | output
    ${'container_scanning'}  | ${true}
    ${'dependency_scanning'} | ${true}
    ${'sast'}                | ${false}
  `('returns `$output` when passed `$input`', ({ input, output }) => {
    expect(isScanningReport(input)).toEqual(output);
  });
});
