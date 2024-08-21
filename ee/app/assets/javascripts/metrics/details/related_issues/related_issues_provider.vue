<script>
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPE_ISSUE } from '~/issues/constants';
import { GRAPHQL_METRIC_TYPE } from '../../constants';
import getMetricsRelatedIssues from './graphql/get_metrics_related_issues.query.graphql';

export default {
  props: {
    projectFullPath: {
      type: String,
      required: true,
    },
    metricName: {
      type: String,
      required: true,
    },
    metricType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      relatedIssues: [],
      error: null,
      isLoading: false,
    };
  },
  methods: {
    parseGraphQLObject(obj) {
      if (!obj) return null;

      return {
        ...obj,
        id: getIdFromGraphQLId(obj.id),
      };
    },
    parseGraphQLNodes(nodes) {
      return nodes.map((node) => this.parseGraphQLObject(node));
    },
  },
  apollo: {
    relatedIssues: {
      query: getMetricsRelatedIssues,
      variables() {
        return {
          projectFullPath: this.projectFullPath,
          metricName: this.metricName,
          metricType: GRAPHQL_METRIC_TYPE[this.metricType.toLowerCase()],
        };
      },
      update(data) {
        const links = data.project?.observabilityMetricsLinks?.nodes || [];

        return links.map(({ issue }) => ({
          ...issue,
          id: getIdFromGraphQLId(issue.id),
          path: issue.webUrl,
          type: TYPE_ISSUE,
          milestone: this.parseGraphQLObject(issue.milestone),
          assignees: this.parseGraphQLNodes(issue.assignees.nodes),
        }));
      },
      error(error) {
        this.error = error;
      },
    },
  },
  render() {
    if (!this.$scopedSlots.default) return null;

    return this.$scopedSlots.default({
      issues: this.relatedIssues,
      loading: this.$apollo.loading,
      error: this.error,
    });
  },
};
</script>
