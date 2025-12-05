# Controller Update: Python Backend → PortfolioChatAgent

## What Changed

### ❌ **REMOVED: Python Backend Call**

```ruby
# OLD CODE - REMOVED
@chat_session.ai_chat_messages.create!(
  role: 'user',
  content: params[:message]
)

response = PythonBackendClient.chat(
  message: params[:message],
  section: @current_section.section_type,
  web_search_enabled: @current_section.web_search_enabled
)

ai_message = @chat_session.ai_chat_messages.create!(
  role: 'assistant',
  content: data['response'],
  metadata: { 'sources' => data['sources'] }
)
```

### ✅ **ADDED: PortfolioChatAgent Call**

```ruby
# NEW CODE - ADDED
result = PortfolioChatAgent.call(
  support_agent_id: find_or_create_chat_agent.id,
  target: @chat_session,
  user_message: params[:message]
)

# Agent handles both saving user message AND assistant response
# No manual message creation needed!
```

---

## Key Differences

| Aspect | Python Backend (OLD) | PortfolioChatAgent (NEW) |
|--------|---------------------|-------------------------|
| **Message saving** | Controller saves both manually | Agent saves both automatically |
| **Conversation memory** | ❌ No memory (only current message) | ✅ Full memory (loads all history) |
| **Network calls** | HTTP call to Python service | Pure Ruby/Rails code |
| **Error handling** | HTTP errors, timeouts | Standard Ruby exceptions |
| **Tool execution** | Python handles web search | Agent handles web search |
| **Deployment** | Two services (Rails + Python) | One service (Rails only) |

---

## How It Works Now

### **Request Flow:**

```
1. Frontend sends message
   ↓
2. Controller receives request
   ↓
3. Controller calls PortfolioChatAgent.call(
     target: @chat_session,
     user_message: "What's the revenue?"
   )
   ↓
4. Agent does:
   ├─ Load ALL previous messages from database
   ├─ Create Langchain::Assistant with memory
   ├─ Add new user message
   ├─ Run assistant (with full context!)
   ├─ Save user message to database
   └─ Save assistant response to database
   ↓
5. Controller receives result[:ai_response]
   ↓
6. Controller returns JSON to frontend
```

### **Memory Works Because:**

Every time the agent is called:
1. It loads **ALL** previous messages from `ai_chat_messages`
2. Feeds them into Langchain::Assistant
3. LLM sees full conversation context
4. Generates contextually-aware response

---

## New Helper Methods

### **`find_or_create_chat_session`**
```ruby
def find_or_create_chat_session
  @report.ai_chat_sessions.find_or_create_by!(analyst_id: current_user.id)
end
```
- Creates one chat session per analyst per report
- Reuses same session for all messages (maintains continuity)

### **`find_or_create_chat_agent`**
```ruby
def find_or_create_chat_agent
  SupportAgent.find_or_create_by!(
    agent_type: 'PortfolioChatAgent',
    entity_id: current_user.entity_id
  ) do |agent|
    agent.name = "Portfolio Chat Assistant"
    agent.enabled = true
  end
end
```
- Creates the SupportAgent record for PortfolioChatAgent
- One per entity (shared across all reports in the entity)
- Stores configuration in `json_fields`

---

## New Endpoint: `index`

```ruby
def index
  # Returns chat history for a session
  messages = @chat_session.ai_chat_messages.order(:created_at)
  render json: { messages: messages }
end
```

**Usage:**
```
GET /ai_portfolio_reports/:id/ai_chat_messages
```

**Returns:**
```json
{
  "success": true,
  "session_id": 123,
  "messages": [
    {
      "id": 1,
      "role": "user",
      "content": "What's the revenue?",
      "created_at": "2025-12-05T10:00:00Z"
    },
    {
      "id": 2,
      "role": "assistant",
      "content": "The revenue is $385B...",
      "created_at": "2025-12-05T10:00:05Z"
    }
  ]
}
```

---

## Error Handling Changes

### **Before (Python Backend):**
```ruby
rescue StandardError => e
  Rails.logger.error "Python backend error: #{e.message}"
  render json: { success: false, error: e.message }
end
```

### **After (Agent):**
```ruby
if result.success?
  # Handle success
else
  # Agent returned failure
  Rails.logger.error "[AiChatMessagesController] Agent error: #{result[:error]}"
  render json: { success: false, error: result[:error] }
end
rescue StandardError => e
  # Unexpected exception
  Rails.logger.error "[AiChatMessagesController] Error: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")
  render json: { success: false, error: "Chat error: #{e.message}" }
end
```

**Benefits:**
- Clear distinction between agent failures and exceptions
- Better logging with context
- Full backtrace in logs for debugging

---

## What No Longer Matters

### ❌ **Removed Dependencies:**
- `@current_section` - Agent doesn't need section context
- `PythonBackendClient` - No longer used
- Manual message creation - Agent handles it

### ❌ **Removed Parameters:**
These parameters were Python-backend specific:
- `section: @current_section.section_type`
- `web_search_enabled: @current_section.web_search_enabled`

Agent decides when to use web search automatically based on the question!

---

## Testing the Updated Controller

### **In Rails Console:**

```ruby
# 1. Create test data
report = AiPortfolioReport.first
user = User.first

# 2. Simulate controller action
controller_params = {
  ai_portfolio_report_id: report.id,
  message: "Tell me about this company",
  chat_session_id: nil  # Will create new session
}

# 3. Test the flow
chat_session = report.ai_chat_sessions.find_or_create_by!(analyst_id: user.id)

result = PortfolioChatAgent.call(
  support_agent_id: SupportAgent.find_or_create_by!(
    agent_type: 'PortfolioChatAgent',
    entity_id: user.entity_id,
    name: "Portfolio Chat Assistant",
    enabled: true
  ).id,
  target: chat_session,
  user_message: "Tell me about this company"
)

puts result[:ai_response]
```

### **Via HTTP (curl):**

```bash
# Assuming you're logged in and have a valid session
curl -X POST http://localhost:3000/ai_portfolio_reports/1/ai_chat_messages \
  -H "Content-Type: application/json" \
  -H "Cookie: _session_id=YOUR_SESSION_ID" \
  -d '{
    "message": "What is the company revenue?",
    "session_id": null
  }'
```

### **Expected Response:**

```json
{
  "success": true,
  "message_id": 123,
  "response": "Based on the available information, the company's revenue is...",
  "sources": null,
  "session_id": 456
}
```

---

## Migration Checklist

- [x] ✅ Created PortfolioChatAgent
- [x] ✅ Created WebSearchTool
- [x] ✅ Updated SupportAgent model
- [x] ✅ Updated AiChatMessagesController
- [ ] ⏳ Test in Rails console
- [ ] ⏳ Test via browser/Postman
- [ ] ⏳ Verify memory works (follow-up messages)
- [ ] ⏳ Verify web search tool works
- [ ] ⏳ Remove PythonBackendClient references (after testing)
- [ ] ⏳ Update frontend if needed
- [ ] ⏳ Deploy to staging

---

## Next Steps

1. **Test in Rails Console** (Step 3)
2. **Test via Browser** (Step 4)
3. **Verify Memory Works** (Step 5)
4. **Remove Python Backend** (Step 6)

Ready to test! 🚀
