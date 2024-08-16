<script>
import getRelatedIssues from './graphql/get_related_issues.query.graphql';

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
  apollo: {
    relatedIssues: {
      query: getRelatedIssues,
      variables() {
        return {
          projectFullPath: this.projectFullPath,
          metricName: this.metricName,
          metricType: this.metricType,
        };
      },
      update(data) {
        return data.project?.issues?.nodes || [];
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
