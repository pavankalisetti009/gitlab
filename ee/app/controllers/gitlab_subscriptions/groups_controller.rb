# frozen_string_literal: true

module GitlabSubscriptions
  class GroupsController < ApplicationController
    layout 'minimal'

    before_action :authenticate_user!

    feature_category :subscription_management
    urgency :low

    def new
      @plan_data = find_plan
      @promo_code = subscription_params[:promo_code]

      return not_found unless @plan_data

      @eligible_groups = GitlabSubscriptions::PurchaseEligibleNamespacesFinder.new(
        user: current_user,
        plan_id: @plan_data[:id]
      ).execute
    end

    def create
      name = group_params[:name]
      path = Namespace.clean_path(group_params[:path] || name)

      response = Groups::CreateService.new(
        current_user, name: name, path: path, organization_id: Current.organization.id
      ).execute

      if response.success?
        render json: { id: response[:group].id }, status: :created
      else
        render json: { errors: response[:group]&.errors }, status: :unprocessable_entity
      end
    end

    private

    def group_params
      params.require(:group).permit(:name, :path, :visibility_level)
    end

    def subscription_params
      params.permit(:plan_id, :promo_code)
    end

    def find_plan
      return unless subscription_params[:plan_id]

      all_plans = GitlabSubscriptions::FetchSubscriptionPlansService.new(plan: :free).execute

      all_plans.find { |plan| plan[:id] == subscription_params[:plan_id] }
    end
  end
end
