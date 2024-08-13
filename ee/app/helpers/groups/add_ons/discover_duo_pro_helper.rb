# frozen_string_literal: true

module Groups
  module AddOns
    module DiscoverDuoProHelper
      def duo_pro_documentation_link_track_action(namespace)
        if GitlabSubscriptions::DuoPro.active_trial_add_on_purchase_for_namespace?(namespace)
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
            header: s_("DuoProDiscover|Test generation"),
            body: s_("DuoProDiscover|Automates repetitive tasks and helps catch bugs early."),
            link_text: s_("DuoProDiscover|Read documentation"),
            link_path: help_page_path("user/gitlab_duo_chat", anchor: "write-tests-in-the-ide"),
            track_label: 'test_generation_feature',
            track_action: duo_pro_documentation_link_track_action(namespace)
          },
          {
            header: s_("DuoProDiscover|Code explanation"),
            body: s_("DuoProDiscover|Helps you understand code by explaining it in natural language."),
            link_text: s_("DuoProDiscover|Read documentation"),
            link_path: help_page_path("user/ai_experiments",
              anchor: "explain-code-in-the-web-ui-with-code-explanation"),
            track_label: 'code_explanation_feature',
            track_action: duo_pro_documentation_link_track_action(namespace)
          },
          {
            header: s_("DuoProDiscover|Code refactoring"),
            body: s_("DuoProDiscover|Work to improve existing code quality."),
            link_text: s_("DuoProDiscover|Read documentation"),
            link_path: help_page_path("user/gitlab_duo_chat", anchor: "refactor-code-in-the-ide"),
            track_label: 'code_refactoring_feature',
            track_action: duo_pro_documentation_link_track_action(namespace)
          },
          {
            header: s_("DuoProDiscover|Chat from any location"),
            body: s_("DuoProDiscover|Access Chat from the GitLab UI or your preferred IDE."),
            link_text: s_("DuoProDiscover|Read documentation"),
            link_path: help_page_url("user/gitlab_duo_chat", anchor: "use-gitlab-duo-chat-in-the-web-ide"),
            track_label: 'chat_feature',
            track_action: duo_pro_documentation_link_track_action(namespace)
          }
        ]
      end
    end
  end
end
