# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/empty', feature_category: :groups_and_projects do
  before do
    assign(:project, ProjectPresenter.new(build(:project), current_user: nil))
    stub_template 'projects/_sidebar.html.haml' => ''
  end

  subject { render && rendered }

  it { is_expected.to render_template('projects/_duo_free_access_ending_banner') }
end
