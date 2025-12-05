# Phase 1: PortfolioChatAgent - File Structure Setup

## Files Created/Modified

### 1. ✅ Created: `app/packs/ai/support_agents/services/portfolio_chat_agent.rb`
**Purpose:** Main agent service for conversational AI with memory

**Key Features:**
- Inherits from `SupportAgentService` (consistent with existing agents)
- Uses Langchain::Assistant for automatic memory management
- Implements Trailblazer operation pattern with steps:
  - `initialize_agent` (inherited)
  - `setup_langchain_assistant` - creates assistant and loads history
  - `execute_chat` - processes user message with full context
  - `persist_conversation` - saves to database

**Tool Methods:**
- `web_search(query:)` - DuckDuckGo search tool

**Helper Methods:**
- `initialize_langchain_llm` - sets up OpenAI client
- `build_system_instructions` - creates context-aware system prompt
- `load_conversation_history` - loads from ai_chat_messages into assistant
- `message_exists_in_session?` - prevents duplicate saves
- `extract_message_metadata` - captures tool usage info
- `format_search_results_for_llm` - formats search results for LLM

---

### 2. ✅ Created: `lib/agent_tools/web_search_tool.rb`
**Purpose:** Web search functionality using DuckDuckGo API

**Methods:**
- `AgentTools::WebSearchTool.search(query)` - main search method
- `parse_results` - parses DuckDuckGo JSON response
- `extract_related_topics` - gets related information
- `extract_sources` - collects source URLs

**Returns:**
```ruby
{
  abstract: "Main summary",
  abstract_text: "Detailed text",
  abstract_source: "Source name",
  abstract_url: "URL",
  related_topics: ["topic 1", "topic 2"],
  sources: ["url1", "url2"]
}
```

---

### 3. ✅ Modified: `app/packs/ai/support_agents/models/support_agent.rb`
**Change:** Added `PortfolioChatAgent` to `AGENT_TYPES` array

**Before:**
```ruby
AGENT_TYPES = %w[KycOnboardingAgent PortfolioCompanyAgent PortfolioReportingAgent1].freeze
```

**After:**
```ruby
AGENT_TYPES = %w[KycOnboardingAgent PortfolioCompanyAgent PortfolioReportingAgent1 PortfolioChatAgent].freeze
```

---

## Directory Structure Created

```
app/packs/ai/support_agents/services/
└── portfolio_chat_agent.rb          ← NEW

lib/agent_tools/                     ← NEW DIRECTORY
└── web_search_tool.rb               ← NEW
```

---

## Next Steps

### Step 2: Update Controller
Modify `app/packs/ai/ai_portfolio_reports/controllers/ai_chat_messages_controller.rb` to call the new agent instead of Python backend.

### Step 3: Configure Credentials
Ensure OpenAI API key is set:
```bash
# Option 1: Rails credentials
EDITOR="code --wait" rails credentials:edit
# Add: openai: { api_key: "sk-..." }

# Option 2: Environment variable
export OPENAI_API_KEY="sk-..."
```

### Step 4: Test in Rails Console
```ruby
# Create or find a chat session
report = AiPortfolioReport.first
chat = report.ai_chat_sessions.first_or_create!(analyst: User.first)

# Call the agent
result = PortfolioChatAgent.call(
  support_agent_id: SupportAgent.find_or_create_by(
    agent_type: 'PortfolioChatAgent',
    entity_id: report.portfolio_company.entity_id
  ).id,
  target: chat,
  user_message: "Hello, tell me about this company"
)

# Check result
puts result[:ai_response]
```

### Step 5: Update Routes
Ensure routes are in place for chat messages endpoint.

---

## Configuration Requirements

### Required Gems (Already in Gemfile)
- ✅ `langchainrb` - for Langchain::Assistant
- ✅ `ruby-openai` - for OpenAI API
- ✅ `httparty` - for web search

### Environment Variables
- `OPENAI_API_KEY` - OpenAI API key (required)
- `CHAT_AGENT_MODEL` - Model name (optional, defaults to 'gpt-4o-mini')

### Database Tables (Already Exist)
- ✅ `support_agents` - agent configuration
- ✅ `ai_chat_sessions` - chat sessions
- ✅ `ai_chat_messages` - message history

---

## How It Works

### Memory Management Flow:

1. **User sends message** → Controller receives request
2. **Controller calls agent:**
   ```ruby
   PortfolioChatAgent.call(
     support_agent_id: agent.id,
     target: chat_session,
     user_message: "What's the revenue?"
   )
   ```
3. **Agent initializes:**
   - Creates Langchain::Assistant
   - Loads ALL previous messages from `ai_chat_messages` table
   - Adds them to assistant's memory
4. **Agent processes message:**
   - Adds new user message to assistant
   - Runs assistant (which has full context)
   - Assistant can call tools (web_search) if needed
5. **Agent persists:**
   - Saves user message to database
   - Saves assistant response to database
6. **Controller returns** JSON with response

### Next message maintains memory because:
- Agent loads ALL messages again (including the one just saved)
- Langchain::Assistant manages the conversation context
- LLM receives full history every time

---

## Testing Checklist

- [ ] Agent file loads without errors
- [ ] WebSearchTool works independently
- [ ] Can create PortfolioChatAgent support agent record
- [ ] Can call agent with test message
- [ ] Messages persist to database
- [ ] Follow-up message has context (tests memory)
- [ ] Web search tool gets called when appropriate
- [ ] Controller updated and working
- [ ] Frontend can send/receive messages

---

## Known Limitations & Future Enhancements

### Current Limitations:
- Full history sent every time (token usage grows)
- No conversation summarization
- No streaming responses
- Web search is basic (DuckDuckGo Instant Answers only)

### Future Enhancements (Phase 4):
- Sliding window or summarization for long conversations
- Streaming responses via Server-Sent Events
- Better web search (multiple sources, ranking)
- Additional tools (document access, data queries)
- Conversation branching/forking
- Export conversation history

---

## Architecture Diagram

```
User Input
    ↓
AiChatMessagesController
    ↓
PortfolioChatAgent.call
    ↓
├─ initialize_agent (inherited)
├─ setup_langchain_assistant
│    ├─ Create Langchain::Assistant
│    ├─ Load history from ai_chat_messages
│    └─ Set system instructions
├─ execute_chat
│    ├─ Add user message to assistant
│    ├─ assistant.run (memory managed automatically!)
│    └─ Extract response
└─ persist_conversation
     ├─ Save user message to ai_chat_messages
     └─ Save assistant response to ai_chat_messages
    ↓
Response returned to controller → JSON to frontend
```

---

## File Structure Complete ✅

All files for Phase 1 have been created. Ready to proceed with Step 2: Update Controller!
