# frozen_string_literal: true

module QA
  # This test requires several feature flags, user settings, and instance configuration.
  # See https://docs.gitlab.com/ee/development/code_suggestions/#code-suggestions-development-setup
  RSpec.describe 'Create', product_group: :remote_development do
    describe 'Code Suggestions in Web IDE' do
      let(:project) { create(:project, :with_readme, name: 'webide-code-suggestions-project') }
      let(:file_name) { 'new_file.rb' }
      let(:prompt_data) { 'def reverse_string' }

      before do
        Flow::Login.sign_in

        create(:commit, project: project, actions: [
          { action: 'create', file_path: file_name, content: '# test' }
        ])

        project.visit!
        Page::Project::Show.perform(&:open_web_ide!)
        Page::Project::WebIDE::VSCode.perform do |ide|
          ide.wait_for_ide_to_load(file_name)
        end
      end

      shared_examples 'a code generation suggestion' do |testcase|
        it 'returns a code generation suggestion which can be accepted', testcase: testcase do
          Page::Project::WebIDE::VSCode.perform do |ide|
            ide.add_prompt_into_a_file(file_name, prompt_data)
            previous_content_length = ide.editor_content_length

            # code generation will put suggestion on the next line
            ide.wait_for_code_suggestion
            expect(ide.editor_content_length).to be > previous_content_length, "Expected a suggestion"

            ide.accept_code_suggestion
            expect(ide.editor_content_length).to be > previous_content_length, "Expected accepted suggestion in file"
          end
        end
      end

      shared_examples 'a code completion suggestion' do |testcase|
        # We should avoid the use of . in the prompt since the remote Selenium WebDriver
        # also uses send_keys to upload files if it finds the text matches a potential file name,
        # which can cause unintended behavior in the test.
        #
        # The remote WebDriver is used in orchestrated tests that make use of Selenoid video recording.
        # https://www.selenium.dev/documentation/webdriver/elements/file_upload/
        let(:prompt_data) { "def set_name(whitespace_name)\n    @name = " }

        it 'returns a code completion suggestion which can be accepted', testcase: testcase do
          Page::Project::WebIDE::VSCode.perform do |ide|
            ide.add_prompt_into_a_file(file_name, prompt_data)
            previous_content_length = ide.editor_content_length

            # code completion will put suggestion on the same line
            ide.wait_for_code_suggestion
            expect(ide.editor_content_length).to be > previous_content_length, 'Expected a suggestion'

            ide.accept_code_suggestion
            expect(ide.editor_content_length).to be > previous_content_length, 'Expected accepted suggestion in file'
          end
        end
      end

      shared_examples 'unauthorized' do |testcase|
        it 'returns no suggestion', testcase: testcase do
          Page::Project::WebIDE::VSCode.perform do |ide|
            ide.add_prompt_into_a_file(file_name, prompt_data, wait_for_code_suggestions: false)
            previous_content_length = ide.editor_content_length

            expect(ide).to have_code_suggestions_disabled

            expect(ide.editor_content_length).to eq(previous_content_length), "Expected no suggestion"
          end
        end
      end

      context 'on GitLab.com', :smoke, :external_ai_provider,
        only: { pipeline: %i[staging staging-canary canary production] } do
        it_behaves_like 'a code generation suggestion',
          'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/425756'

        it_behaves_like 'a code completion suggestion',
          'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/437111'
      end

      context 'on Self-managed', :orchestrated do
        context 'with a valid license' do
          context 'with a Duo Pro add-on' do
            context 'when seat is assigned', :ai_gateway do
              it_behaves_like 'a code completion suggestion',
                'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/439625'
            end

            context 'when seat is not assigned', :ai_gateway_no_seat_assigned do
              it_behaves_like 'unauthorized', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/451486'
            end
          end

          context 'with no Duo Pro add-on', :blocking, :ai_gateway_no_add_on do
            it_behaves_like 'unauthorized', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/452450'
          end
        end

        context 'with no license', :blocking, :ai_gateway_no_license do
          it_behaves_like 'unauthorized', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/448662'
        end
      end
    end
  end
end
