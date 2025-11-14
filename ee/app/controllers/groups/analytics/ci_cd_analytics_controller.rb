# frozen_string_literal: true

class Groups::Analytics::CiCdAnalyticsController < Groups::Analytics::ApplicationController
  include ProductAnalyticsTracking

  layout 'group'

  before_action -> { check_feature_availability!(:group_ci_cd_analytics) }
  before_action -> { authorize_view_by_action!(:view_group_ci_cd_analytics) }

  track_event :show,
    name: 'g_analytics_ci_cd_release_statistics',
    conditions: -> { should_track_ci_cd_release_statistics? }

  def show; end

  def should_track_ci_cd_release_statistics?
    params[:tab].blank? || params[:tab] == 'release-statistics'
  end
end
