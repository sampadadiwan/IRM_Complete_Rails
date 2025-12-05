class AiChatMessagesController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  skip_before_action :verify_authenticity_token, only: [:create]

  def create
    @report = AiPortfolioReport.find(params[:ai_portfolio_report_id])
    @chat_session = find_or_create_chat_session
    @current_section = @report.ai_report_sections.find(params[:section_id]) if params[:section_id].present?

    # Call PortfolioChatAgent instead of Python backend
    begin
      result = PortfolioChatAgent.call(
        support_agent_id: find_or_create_chat_agent.id,
        target: @chat_session,
        user_message: params[:message]
      )

      if result.success?
        # Get the last message saved by the agent (assistant's response)
        ai_message = @chat_session.ai_chat_messages.where(role: 'assistant').last

        render json: {
          success: true,
          message_id: ai_message&.id,
          response: result[:ai_response],
          sources: ai_message&.metadata&.dig('sources'),
          session_id: @chat_session.id
        }
      else
        Rails.logger.error "[AiChatMessagesController] Agent error: #{result[:error]}"
        render json: { 
          success: false, 
          error: result[:error] || 'Agent execution failed' 
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "[AiChatMessagesController] Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: { 
        success: false, 
        error: "Chat error: #{e.message}" 
      }, status: :internal_server_error
    end
  end

  # Optional: Add endpoint to list chat history
  def index
    @report = AiPortfolioReport.find(params[:ai_portfolio_report_id])
    @chat_session = @report.ai_chat_sessions.find_by(id: params[:chat_session_id]) || @report.ai_chat_sessions.first

    if @chat_session
      messages = @chat_session.ai_chat_messages.order(:created_at).map do |msg|
        {
          id: msg.id,
          role: msg.role,
          content: msg.content,
          created_at: msg.created_at,
          metadata: msg.metadata
        }
      end

      render json: { 
        success: true,
        session_id: @chat_session.id,
        messages: messages 
      }
    else
      render json: { 
        success: true,
        session_id: nil,
        messages: [] 
      }
    end
  end

  private

  # Finds or creates a chat session for the current analyst
  def find_or_create_chat_session
    @report.ai_chat_sessions.find_or_create_by!(analyst_id: current_user.id)
  end

  # Finds or creates the PortfolioChatAgent support agent for this entity
  def find_or_create_chat_agent
    SupportAgent.find_or_create_by!(
      agent_type: 'PortfolioChatAgent',
      entity_id: current_user.entity_id
    ) do |agent|
      agent.name = "Portfolio Chat Assistant"
      agent.enabled = true
      agent.json_fields = {
        'model' => ENV['CHAT_AGENT_MODEL'] || 'gpt-4o-mini',
        'temperature' => '0.7'
      }
    end
  end
end
