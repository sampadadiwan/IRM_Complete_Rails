class PortfolioChatAgent < SupportAgentService
  # PortfolioChatAgent provides conversational AI assistance for portfolio reports
  # with full conversation memory and tool execution capabilities.
  #
  # Unlike other agents, this is STATEFUL - it maintains conversation history
  # across multiple interactions using Langchain::Assistant for automatic memory management.
  #
  # == Features ==
  # - Full conversation memory (loads from ai_chat_messages)
  # - Tool execution (web search, data queries)
  # - Context-aware responses
  # - Persistent conversation history
  #
  # == Usage ==
  # result = PortfolioChatAgent.call(
  #   support_agent_id: agent.id,
  #   target: ai_chat_session,
  #   user_message: "What's the company's revenue?"
  # )

  # Override parent's initialize_agent to skip RubyLLM initialization
  # PortfolioChatAgent uses Langchain instead
  step :initialize_chat_agent
  step :setup_langchain_assistant
  step :execute_chat
  step :persist_conversation

  # == Tool Methods ==
  # These methods can be called by the Langchain Assistant during execution

  # Searches the web using DuckDuckGo
  # @param query [String] search query
  # @return [Hash] search results with abstract and sources
  def web_search(query:)
    Rails.logger.info "[PortfolioChatAgent] Tool called: web_search(#{query})"
    
    require_relative '../../../../lib/agent_tools/web_search_tool'
    results = AgentTools::WebSearchTool.search(query)
    
    format_search_results_for_llm(results)
  end

  private

  # Initialize chat agent - simpler than parent's initialize_agent
  # We don't need RubyLLM since we use Langchain
  def initialize_chat_agent(ctx, **)
    @support_agent = SupportAgent.find(ctx[:support_agent_id])
    ctx[:support_agent] = @support_agent
    # No LLM initialization here - handled in setup_langchain_assistant
  end

  # Sets up the Langchain Assistant with conversation history
  # This is where the magic happens - assistant manages memory automatically!
  #
  # @param ctx [Hash] execution context
  # @param target [AiChatSession] the chat session to work with
  def setup_langchain_assistant(ctx, target:, **)
    chat_session = target
    
    Rails.logger.info "[PortfolioChatAgent] Setting up assistant for chat session #{chat_session.id}"
    
    # Initialize Langchain LLM
    llm = initialize_langchain_llm
    
    # Create assistant with tools
    assistant = Langchain::Assistant.new(
      llm: llm,
      tools: [self], # This agent provides tool methods
      instructions: build_system_instructions(chat_session)
    )
    
    # Load conversation history from database into assistant
    load_conversation_history(chat_session, assistant)
    
    ctx[:assistant] = assistant
    ctx[:chat_session] = chat_session
    
    Rails.logger.info "[PortfolioChatAgent] Loaded #{chat_session.ai_chat_messages.count} previous messages"
  end

  # Executes the chat interaction
  # The assistant automatically manages context and calls tools as needed
  #
  # @param ctx [Hash] execution context
  # @param assistant [Langchain::Assistant] the assistant instance
  def execute_chat(ctx, assistant:, **)
    user_message = ctx[:user_message]
    
    Rails.logger.info "[PortfolioChatAgent] Processing message: #{user_message[0..50]}..."
    
    # Add new user message to assistant
    assistant.add_message(content: user_message)
    
    # Run assistant - it manages memory and tool execution automatically
    assistant.run(auto_tool_execution: true)
    
    # Get response from assistant
    ctx[:ai_response] = assistant.messages[-1].content
    
    Rails.logger.info "[PortfolioChatAgent] Generated response (#{ctx[:ai_response].length} chars)"
  end

  # Persists new messages to database
  # Only saves the messages that aren't already in the database
  #
  # @param ctx [Hash] execution context
  # @param chat_session [AiChatSession] the chat session
  # @param assistant [Langchain::Assistant] the assistant with new messages
  def persist_conversation(ctx, chat_session:, assistant:, **)
    # Get last 2 messages (user message + assistant response)
    new_messages = assistant.messages.last(2)
    
    Rails.logger.info "[PortfolioChatAgent] Persisting #{new_messages.count} new messages"
    
    new_messages.each do |msg|
      # Avoid duplicates - check if message was just created
      unless message_exists_in_session?(chat_session, msg)
        chat_session.ai_chat_messages.create!(
          role: msg.role,
          content: msg.content,
          metadata: extract_message_metadata(msg)
        )
      end
    end
    
    Rails.logger.info "[PortfolioChatAgent] Conversation persisted successfully"
  end

  # == Helper Methods ==

  # Initializes the Langchain LLM client
  # @return [Langchain::LLM::OpenAI] configured LLM instance
  def initialize_langchain_llm
    api_key = Rails.application.credentials.dig(:openai, :api_key) || 
              ENV['OPENAI_API_KEY']
    
    unless api_key
      raise "OpenAI API key not found. Set it in credentials or OPENAI_API_KEY env var"
    end
    
    Langchain::LLM::OpenAI.new(
      api_key: api_key,
      llm_options: { 
        model: ENV['CHAT_AGENT_MODEL'] || 'gpt-4o-mini',
        temperature: 0.7
      }
    )
  end

  # Builds system instructions for the assistant
  # @param chat_session [AiChatSession] the chat session
  # @return [String] system instructions
  def build_system_instructions(chat_session)
    report = chat_session.ai_portfolio_report
    company = report.portfolio_company
    
    <<~INSTRUCTIONS
      You are an AI assistant helping analyze portfolio company: #{company.name}.
      
      Report ID: #{report.id}
      Analyst: #{chat_session.analyst.name}
      Report Date: #{report.report_date}
      
      Your role:
      - Answer questions about the company and report
      - Provide insights and analysis
      - Help refine report sections
      - Use web search when you need current information
      
      Guidelines:
      - Be professional and concise
      - Base responses on facts and data
      - If you don't know something, admit it and suggest searching
      - When referencing report sections, be specific
      - Always cite sources when using web search results
      
      Available tools:
      - web_search: Search the web for current information
    INSTRUCTIONS
  end

  # Loads conversation history from database into assistant
  # @param chat_session [AiChatSession] the chat session
  # @param assistant [Langchain::Assistant] the assistant to load into
  def load_conversation_history(chat_session, assistant)
    chat_session.ai_chat_messages.order(:created_at).each do |msg|
      assistant.add_message(
        role: msg.role,
        content: msg.content
      )
    end
  end

  # Checks if a message already exists in the session
  # @param chat_session [AiChatSession] the chat session
  # @param message [Langchain::Message] the message to check
  # @return [Boolean] true if message exists
  def message_exists_in_session?(chat_session, message)
    chat_session.ai_chat_messages.exists?(
      role: message.role,
      content: message.content,
      created_at: 5.seconds.ago..Time.current
    )
  end

  # Extracts metadata from Langchain message
  # @param message [Langchain::Message] the message
  # @return [Hash] metadata hash
  def extract_message_metadata(message)
    metadata = {}
    
    # Extract tool calls if any
    if message.respond_to?(:tool_calls) && message.tool_calls.present?
      metadata[:tool_calls] = message.tool_calls
    end
    
    metadata
  end

  # Formats search results for LLM consumption
  # @param results [Hash] raw search results
  # @return [String] formatted string for LLM
  def format_search_results_for_llm(results)
    return "No results found" if results[:error] || results.empty?
    
    output = []
    
    if results[:abstract].present?
      output << "Summary: #{results[:abstract]}"
    end
    
    if results[:related_topics].present?
      output << "\nRelated Information:"
      results[:related_topics].each do |topic|
        output << "- #{topic}"
      end
    end
    
    if results[:sources].present?
      output << "\nSources:"
      results[:sources].each do |source|
        output << "- #{source}"
      end
    end
    
    output.join("\n")
  end
end
