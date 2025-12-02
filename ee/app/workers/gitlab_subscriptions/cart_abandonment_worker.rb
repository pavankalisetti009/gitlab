# frozen_string_literal: true

module GitlabSubscriptions
  class CartAbandonmentWorker
    include ApplicationWorker

    data_consistency :sticky
    idempotent!
    urgency :low
    feature_category :subscription_management
    defer_on_database_health_signal :gitlab_main, [:users, :namespaces], 2.minutes
    deduplicate :until_executing, including_scheduled: true, if_deduplicated: :reschedule_once
    loggable_arguments 0, 1, 2, 3

    PRODUCT_INTERACTION_TO_PLAN = {
      'cart abandonment - SaaS Premium' => 'premium',
      'cart abandonment - SaaS Ultimate' => 'ultimate'
    }.freeze

    def perform(user_id, namespace_id, product_interaction, previous_plan_name)
      user = User.find_by_id(user_id)
      namespace = Namespace.find_by_id(namespace_id)

      return unless user && namespace

      return if purchased_paid_plan?(namespace, previous_plan_name)

      send_cart_abandonment_lead(user, namespace, product_interaction)
    end

    private

    def purchased_paid_plan?(namespace, previous_plan_name)
      current_plan_name = namespace.actual_plan_name
      paid_plans = %w[premium ultimate]

      return false if previous_plan_name == current_plan_name

      paid_plans.include?(current_plan_name&.downcase)
    end

    def send_cart_abandonment_lead(user, namespace, product_interaction)
      params = build_lead_params(user, namespace, product_interaction)

      GitlabSubscriptions::CreateHandRaiseLeadService.new.execute(params)
    end

    def build_lead_params(user, namespace, product_interaction)
      {
        product_interaction: product_interaction,
        work_email: user.email,
        opt_in: user.onboarding_status_email_opt_in,
        namespace_id: namespace.id,
        plan_id: plan_id_for_selected_plan(product_interaction, namespace),
        existing_plan: namespace.actual_plan_name,
        skip_country_validation: true
      }.tap do |params|
        params[:role] = user.onboarding_status_role_name if user.onboarding_status_role_name.present?
        if user.preferred_language.present?
          params[:preferred_language] =
            ::Gitlab::I18n.trimmed_language_name(user.preferred_language)
        end
      end
    end

    def plan_id_for_selected_plan(product_interaction, namespace)
      selected_plan = PRODUCT_INTERACTION_TO_PLAN[product_interaction]
      plans_data = GitlabSubscriptions::FetchSubscriptionPlansService.new(
        plan: namespace.plan_name_for_upgrading,
        namespace_id: namespace.id
      ).execute

      return unless plans_data

      plans_data.detect { |plan| plan.code == selected_plan }&.id
    end
  end
end
