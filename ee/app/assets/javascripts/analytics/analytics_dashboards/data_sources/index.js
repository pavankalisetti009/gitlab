export default {
  cube_analytics: () => import('./cube_analytics'),
  value_stream: () => import('./value_stream'),
  usage_overview: () => import('./usage_overview'),
  dora_metrics_over_time: () => import('./dora_metrics_over_time'),
  dora_metrics_by_project: () => import('./dora_metrics_by_project'),
  ai_impact_over_time: () => import('./ai_impact_over_time'),
};
