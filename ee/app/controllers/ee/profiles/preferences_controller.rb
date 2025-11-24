# frozen_string_literal: true

module EE::Profiles::PreferencesController
  extend ::Gitlab::Utils::Override

  override :preferences_param_names
  def preferences_param_names
    super + preferences_param_names_ee
  end

  def preferences_param_names_ee
    params_ee = []

    params_ee.push(:duo_default_namespace_id)
    params_ee.push(:group_view) if License.feature_available?(:security_dashboard)

    params_ee
  end
end
