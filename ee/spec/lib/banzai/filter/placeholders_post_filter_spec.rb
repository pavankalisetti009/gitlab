# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::PlaceholdersPostFilter, feature_category: :markdown do
  def run_pipeline(text, context = { project: project })
    stub_commonmark_sourcepos_disabled

    Banzai.render_and_post_process(text, context)
  end

  let!(:latest_tag) { "<span data-placeholder=\"%{latest_tag}\">#{project_tag}</span>" }
  let!(:project_tag) do
    if project.repository_exists?
      TagsFinder.new(project.repository, per_page: 1, sort: 'updated_desc')&.execute&.first&.name
    end
  end

  context 'when tag has js- triggers' do
    let_it_be(:xss) do
      '<i/class=js-toggle-container><i/class=js-toggle-lazy-diff>' \
        '<i/class="file-holder"data-lines-path="/flightjs/xss/-/raw/main/a.json">' \
        '<i/class=gl-opacity-0><i/class="modal-backdrop"style="top&colon;-99px">' \
        '<i/class=diff-content><table><tbody/>'
    end

    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :small_repo, group: group, create_tag: xss) }
    let!(:scoped_label) { create(:label, name: 'key::value', description: 'xss %{latest_tag}', project: project) }

    before do
      stub_licensed_features(scoped_labels: true)

      project.add_member(user, Gitlab::Access::OWNER)
    end

    it 'sanitizes and removes any js- triggers and tags' do
      expect(Banzai::Filter::SanitizationFilter).to receive(:new).twice.and_call_original

      markdown = '<span data-placeholder>foo ~"key::value"</span>'
      html = run_pipeline(markdown, project: project, current_user: user)

      expect(html).not_to include 'js-'
      expect(html)
        .to include 'title="&lt;span class=\'font-weight-bold\'&gt;Scoped label&lt;/span&gt;&lt;br&gt;xss "'
    end
  end
end
