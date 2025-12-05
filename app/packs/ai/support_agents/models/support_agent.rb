class SupportAgent < ApplicationRecord
  # SupportAgent represents an AI-driven entity responsible for
  # validating consistency between structured fields on a model
  # and extracted values from uploaded documents. It leverages LLMs
  # (Large Language Models) to parse and extract content for verification.
  #
  # Includes:
  #   - WithCustomField: adds support for attaching custom metadata/fields
  #   - WithFolder: provides organization of agents into folders
  #
  # Validations enforce constraints on agent identity and type to ensure
  # consistent naming and classification.
  include WithCustomField
  include WithFolder
  include SupportAgentHelper

  AGENT_TYPES = %w[KycOnboardingAgent PortfolioCompanyAgent PortfolioReportingAgent1 PortfolioChatAgent].freeze

  belongs_to :entity

  scope :enabled, -> { where(enabled: true) }

  validates :name, presence: true
  validates :name, length: { maximum: 30 }
  validates :agent_type, presence: true
  validates :agent_type, length: { maximum: 30 }

  # Returns the human-readable representation of the SupportAgent
  # In this case, simply the name string.
  #
  # @return [String] the name of the agent
  def to_s
    name
  end

  def agent
    agent_type.constantize
  end
end
