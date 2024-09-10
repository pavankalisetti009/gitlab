# frozen_string_literal: true

module Groups
  module AddOns
    module DiscoverDuoProHelper
      def duo_pro_documentation_link_track_action(namespace)
        if GitlabSubscriptions::Trials::DuoPro.active_add_on_purchase_for_namespace?(namespace)
          'click_documentation_link_duo_pro_trial_active'
        else
          'click_documentation_link_duo_pro_trial_expired'
        end
      end

      def duo_pro_discover_card_collection(namespace)
        [
          {
            header: s_("DuoProDiscover|Accelerate your path to market"),
            body: s_(
              "DuoProDiscover|Develop and deploy secure software faster with AI in every phase " \
                "of the software development lifecycle — from planning and code creation to testing, " \
                "security, and monitoring."
            )
          },
          {
            header: s_("DuoProDiscover|Adopt AI with guardrails"),
            body: s_(
              "DuoProDiscover|With GitLab Duo, you control which users, projects, and groups can use " \
                "AI-powered capabilities. Also, your organization's proprietary code and data aren't used " \
                "to train AI models."
            )
          },
          {
            header: s_("DuoProDiscover|Improve developer experience"),
            body: s_(
              "DuoProDiscover|Give your developers a single platform that integrates the best AI model " \
                "for each use case across the entire workflow, from understanding code to fixing security " \
                "vulnerabilities."
            )
          },
          {
            header: s_("DuoProDiscover|Committed to transparent AI"),
            body: safe_format(
              s_(
                "DuoProDiscover|For organizations and teams to trust AI, it must be transparent. " \
                  "GitLab's %{link_start}AI Transparency Center%{link_end} details how we uphold ethics and " \
                  "transparency in our AI-powered features."
              ),
              tag_pair(
                link_to('', 'https://about.gitlab.com/ai-transparency-center/',
                  data: {
                    track_action: duo_pro_documentation_link_track_action(namespace),
                    track_label: 'ai_transparency_center_feature'
                  },
                  class: 'gl-contents',
                  target: "_blank",
                  rel: "noopener noreferrer"),
                :link_start,
                :link_end
              )
            )
          }
        ]
      end

      def duo_pro_whats_new_card_collection(namespace)
        [
          {
            header: s_("DuoProDiscover|Test Generation"),
            body: s_("DuoProDiscover|Automates repetitive tasks and helps catch bugs early."),
            footer: render_footer_link(
              link_text: s_("DuoProDiscover|Read documentation"),
              link_path: help_page_path("user/gitlab_duo_chat/examples", anchor: "write-tests-in-the-ide"),
              track_label: 'test_generation_feature',
              track_action: duo_pro_documentation_link_track_action(namespace)
            )
          },
          {
            header: s_("DuoProDiscover|Code Explanation"),
            body: s_("DuoProDiscover|Helps you understand code by explaining it in natural language."),
            footer: render_footer_link(
              link_text: s_("DuoProDiscover|Read documentation"),
              link_path: help_page_path("user/gitlab_duo_chat/examples",
                anchor: "explain-code-in-the-ide"),
              track_label: 'code_explanation_feature',
              track_action: duo_pro_documentation_link_track_action(namespace)
            )
          },
          {
            header: s_("DuoProDiscover|Code Refactoring"),
            body: s_("DuoProDiscover|Work to improve existing code quality."),
            footer: render_footer_link(
              link_text: s_("DuoProDiscover|Read documentation"),
              link_path: help_page_path("user/gitlab_duo_chat/examples", anchor: "refactor-code-in-the-ide"),
              track_label: 'code_refactoring_feature',
              track_action: duo_pro_documentation_link_track_action(namespace)
            )
          },
          {
            header: s_("DuoProDiscover|Chat from any location"),
            body: s_("DuoProDiscover|Access Chat from the GitLab UI or your preferred IDE."),
            footer: render_footer_link(
              link_text: s_("DuoProDiscover|Read documentation"),
              link_path: help_page_path("user/gitlab_duo_chat/index", anchor: "supported-editor-extensions"),
              track_label: 'chat_feature',
              track_action: duo_pro_documentation_link_track_action(namespace)
            )
          }
        ]
      end

      def duo_pro_code_suggestions_card_collection(namespace)
        [
          {
            header: s_("DuoProDiscover|Code generation"),
            body: s_("DuoProDiscover|Automatically generate lines of code, " \
              "including full functions, from single and multi-line comments " \
              "as well as comment blocks."),
            footer: render_footer_link(
              link_path: help_page_path("user/project/repository/code_suggestions", anchor: "use-code-suggestions"),
              link_text: s_("DuoProDiscover|Read documentation"),
              track_action: duo_pro_documentation_link_track_action(namespace),
              track_label: 'code_generation_feature',
              icon: "external-link"
            )
          },
          {
            header: s_("DuoProDiscover|Code completion"),
            body: s_("DuoProDiscover|Automatically generate new lines of code from a few typed characters."),
            footer: render_footer_link(
              link_path: "https://gitlab.navattic.com/code-suggestions",
              link_text: s_("DuoProDiscover|Launch Demo"),
              track_action: duo_pro_documentation_link_track_action(namespace),
              track_label: 'code_completion_feature',
              icon: "live-preview"
            )
          },
          {
            header: s_("DuoProDiscover|Language and IDE support"),
            body: s_("DuoProDiscover|Available in 15 languages, including C++, " \
              "C#, Go, Java, JavaScript, Python, PHP, Ruby, Rust, Scala, Kotlin, " \
              "and TypeScript. And you can use your favorite IDE — VS Code, Visual Studio, " \
              "JetBrains' suite of IDEs, and Neovim are all supported.")
          }
        ]
      end

      def render_footer_link(link_path:, link_text:, track_action:, track_label:, icon: nil)
        link_to(link_path,
          class: 'gl-link',
          target: '_blank',
          rel: 'noopener noreferrer',
          data: {
            track_label: track_label,
            track_action: track_action
          }) do
          concat(link_text)
          concat(sprite_icon(icon, css_class: 'gl-icon gl-ml-2')) if icon.present?
        end
      end
    end
  end
end
