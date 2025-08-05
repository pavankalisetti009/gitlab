import { REGEXES } from 'ee/vulnerabilities/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { isAbsolute, isValidURL } from '~/lib/utils/url_utility';

// Get the issue in the format expected by the descendant components of related_issues_block.vue.
export const getFormattedIssue = (issue) => ({
  ...issue,
  id: getIdFromGraphQLId(issue.id), // Convert GraphQL ID to numeric ID
  iid: parseInt(issue.iid, 10), // Convert iid to number
  path: issue.webUrl,
});

export const getAddRelatedIssueRequestParams = (reference, defaultProjectPath) => {
  let issueIid = reference;
  let projectPath = defaultProjectPath;

  // If the reference is an issue number, parse out just the issue number.
  if (REGEXES.ISSUE_FORMAT.test(reference)) {
    [, issueIid] = REGEXES.ISSUE_FORMAT.exec(reference);
  }
  // If the reference is an absolute URL and matches the issues URL format, parse out the project and issue.
  else if (isValidURL(reference) && isAbsolute(reference)) {
    const { pathname } = new URL(reference);

    if (REGEXES.LINK_FORMAT.test(pathname)) {
      [, projectPath, issueIid] = REGEXES.LINK_FORMAT.exec(pathname);
    }
  }

  return { issueIid, projectPath };
};
