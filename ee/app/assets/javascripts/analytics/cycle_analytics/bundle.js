import initFOSSCycleAnalytics from '~/analytics/cycle_analytics';
import initCycleAnalytics from 'ee/analytics/cycle_analytics';

export default () => {
  if (gon?.licensed_features?.cycleAnalyticsForProjects) {
    initCycleAnalytics();
  } else {
    initFOSSCycleAnalytics();
  }
};
