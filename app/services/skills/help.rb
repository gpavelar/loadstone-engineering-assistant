module Skills
  class Help
    extend Skills::Base

    def self.command = "/help"
    def self.skill_name = :help
    def self.label = "Help"
    def self.description = "Show all available commands"
    def self.model = :haiku

    # Help is intercepted in MessagesController and never reaches AgentService.
    # system_prompt is defined to satisfy the contract.
    def self.system_prompt = ""

    def self.help_text
      <<~HELP
        ## 🧭 Loadstone Commands

        #{Skills::Registry.help_markdown}
        **Or just ask a question** — Loadstone can answer natural language queries about your team, tickets, OKRs, and stakeholders.

        *A lodestone for your loadstone.*
      HELP
    end
  end
end
