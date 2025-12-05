# Testing Guide: PortfolioChatAgent

## Prerequisites

### 1. Set OpenAI API Key

**Option A: Rails Credentials**
```bash
EDITOR="code --wait" rails credentials:edit

# Add this:
openai:
  api_key: sk-proj-your-key-here
```

**Option B: Environment Variable**
```bash
export OPENAI_API_KEY="sk-proj-your-key-here"

# Or in .env file:
echo 'OPENAI_API_KEY=sk-proj-your-key-here' >> .env
```

### 2. Verify Gems Installed

```bash
bundle install
```

Should have:
- ✅ `langchainrb`
- ✅ `ruby-openai`
- ✅ `httparty`

---

## Test 1: Rails Console - Basic Agent Call

```ruby
rails console

# Load required data
report = AiPortfolioReport.first
user = User.first

# If no report exists, create one:
if report.nil?
  company = Investor.first
  report = AiPortfolioReport.create!(
    portfolio_company: company,
    analyst: user,
    status: 'draft',
    report_date: Date.today
  )
end

# Create chat session
chat = report.ai_chat_sessions.create!(analyst: user)

# Create support agent
agent = SupportAgent.create!(
  agent_type: 'PortfolioChatAgent',
  entity_id: user.entity_id,
  name: 'Portfolio Chat Assistant',
  enabled: true
)

# TEST 1: First message
result = PortfolioChatAgent.call(
  support_agent_id: agent.id,
  target: chat,
  user_message: "Hello! Can you tell me about #{report.portfolio_company.name}?"
)

# Check result
puts "Success: #{result.success?}"
puts "Response: #{result[:ai_response]}"

# Check database
puts "Messages in DB: #{chat.ai_chat_messages.count}"  # Should be 2 (user + assistant)
chat.ai_chat_messages.each do |msg|
  puts "[#{msg.role}]: #{msg.content[0..100]}..."
end
```

**Expected Output:**
```
Success: true
Response: [AI response about the company]
Messages in DB: 2
[user]: Hello! Can you tell me about...
[assistant]: [AI response]
```

---

## Test 2: Memory - Follow-up Question

```ruby
# Continue in same console session...

# TEST 2: Follow-up question (tests memory!)
result2 = PortfolioChatAgent.call(
  support_agent_id: agent.id,
  target: chat,
  user_message: "What was my first question?"
)

puts "Response: #{result2[:ai_response]}"

# Should reference the previous question!
# Expected: "Your first question was about [company name]"
```

**Expected Output:**
```
Response: Your first question was asking me to tell you about [company name].
```

**✅ If this works, MEMORY IS WORKING!**

---

## Test 3: Web Search Tool

```ruby
# TEST 3: Question that requires web search
result3 = PortfolioChatAgent.call(
  support_agent_id: agent.id,
  target: chat,
  user_message: "What's the latest news about Apple?"
)

puts "Response: #{result3[:ai_response]}"

# Check if web search was used
last_msg = chat.ai_chat_messages.last
puts "Metadata: #{last_msg.metadata.inspect}"
```

**Expected Output:**
```
Response: [Response with current information about Apple]
Metadata: {"tool_calls" => [...]}  # If tool was used
```

---

## Test 4: Controller via HTTP

### Start Rails Server
```bash
rails server
```

### Test with curl

```bash
# Login first to get session cookie, then:

curl -X POST http://localhost:3000/ai_portfolio_reports/1/ai_chat_messages \
  -H "Content-Type: application/json" \
  -H "Cookie: _session_id=YOUR_SESSION_COOKIE" \
  -d '{
    "message": "What is this company about?"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message_id": 123,
  "response": "This company is...",
  "sources": null,
  "session_id": 456
}
```

---

## Test 5: Frontend (if you have UI)

### Test Chat Interface

1. **Open report in browser**
2. **Find chat box**
3. **Send message:** "Tell me about this company"
4. **Wait for response**
5. **Send follow-up:** "What was my previous question?"
6. **Verify:** AI remembers the context

---

## Troubleshooting

### Error: "OpenAI API key not found"

**Solution:**
```ruby
# Check if key is accessible
Rails.application.credentials.dig(:openai, :api_key)
# or
ENV['OPENAI_API_KEY']

# If nil, set it properly (see Prerequisites above)
```

### Error: "uninitialized constant PortfolioChatAgent"

**Solution:**
```ruby
# Reload Rails environment
reload!

# Or restart console
exit
rails console
```

### Error: "Langchain::Assistant not found"

**Solution:**
```bash
# Install missing gem
bundle add langchainrb
bundle install

# Restart console
```

### Messages not saving to database

**Check:**
```ruby
chat = AiChatSession.last
chat.ai_chat_messages.count  # Should increase after each call

# If 0, check logs:
tail -f log/development.log

# Look for errors in persist_conversation step
```

### No response / timeout

**Check:**
```ruby
# Is OpenAI API working?
require 'ruby-openai'
client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
response = client.chat(
  parameters: {
    model: "gpt-4o-mini",
    messages: [{ role: "user", content: "Say hello" }]
  }
)
puts response.dig("choices", 0, "message", "content")
```

### Web search not working

**Test tool directly:**
```ruby
require_relative 'lib/agent_tools/web_search_tool'
results = AgentTools::WebSearchTool.search("Apple Inc")
puts results.inspect

# Should return hash with abstract, sources, etc.
```

---

## Verification Checklist

- [ ] ✅ First message works
- [ ] ✅ Response is saved to database
- [ ] ✅ Follow-up question maintains context (MEMORY WORKS!)
- [ ] ✅ Web search tool can be called
- [ ] ✅ Controller endpoint works
- [ ] ✅ Frontend chat interface works
- [ ] ✅ Multiple sessions work independently
- [ ] ✅ Error handling works gracefully

---

## Success Criteria

### ✅ **Phase 1 Complete When:**

1. **Basic conversation works**
   - Send message → Get response
   - Response saved to database

2. **Memory works**
   - Send follow-up question
   - AI remembers previous context

3. **Tools work**
   - Web search gets called when needed
   - Results included in response

4. **Controller works**
   - HTTP endpoint returns proper JSON
   - No Python backend needed

---

## Next Phase Preview

**Phase 2: PortfolioReportAgent**
- Generate report sections
- Refine sections
- Use web search for sections
- Document context integration

**Phase 3: Polish & Deploy**
- Streaming responses
- Performance optimization
- Remove Python backend completely
- Deploy to production

---

## Need Help?

If tests fail, share:
1. Error message
2. Full stack trace from logs
3. Which test failed
4. Database state (message count, etc.)

Ready to start testing! 🧪
