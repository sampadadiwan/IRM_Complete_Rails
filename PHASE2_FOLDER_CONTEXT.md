# Phase 2: Document Folder Context - Complete Guide

## Summary

Added **document folder context** to PortfolioChatAgent. The AI can now read documents from a local folder and use that information to answer questions!

---

## What Changed

### **PortfolioChatAgent Updates:**

1. **New step:** `load_document_context` - Loads documents before chat
2. **New parameter:** `document_folder_path` - Path to folder with documents
3. **Enhanced system prompt:** Includes document content
4. **Document extraction:** Supports PDF, TXT, MD (DOCX placeholder)

---

## Supported File Types

| Extension | Status | Extraction Method |
|-----------|--------|-------------------|
| `.txt` | ✅ Supported | Direct file read |
| `.md` | ✅ Supported | Direct file read |
| `.pdf` | ✅ Supported | pdf-reader gem |
| `.docx` | ⏳ Placeholder | To be implemented |

---

## How to Use

### **Basic Usage (No Documents):**

```ruby
result = PortfolioChatAgent.call(
  support_agent_id: agent.id,
  target: chat_session,
  user_message: "Hello"
)
# Works like Phase 1 - no document context
```

### **With Document Folder:**

```ruby
result = PortfolioChatAgent.call(
  support_agent_id: agent.id,
  target: chat_session,
  user_message: "What's in the pitch deck?",
  document_folder_path: "/home/user/documents/apple_inc"
)
# AI has access to all documents in that folder!
```

---

## Testing Guide

### **Step 1: Create Test Documents**

```bash
# On Ubuntu
mkdir -p /tmp/test_documents

# Create sample text file
cat > /tmp/test_documents/company_info.txt << EOF
Company: TechCorp
Founded: 2020
Revenue 2023: \$5 Million
Employees: 50
Product: SaaS platform for data analytics
EOF

# Create another sample
cat > /tmp/test_documents/financials.txt << EOF
Q3 2024 Financial Summary
Revenue: \$1.5M
Expenses: \$800K
Profit: \$700K
Growth: 30% YoY
EOF
```

---

### **Step 2: Test in Rails Console**

```ruby
rails console

# Setup
company = Investor.first
analyst = User.first
report = AiPortfolioReport.create!(
  portfolio_company: company,
  analyst: analyst,
  status: 'draft',
  report_date: Date.today
)
chat = report.ai_chat_sessions.create!(analyst: analyst)
agent = SupportAgent.create!(
  agent_type: 'PortfolioChatAgent',
  entity_id: analyst.entity_id,
  name: 'Chat Assistant',
  enabled: true
)

puts "✅ Setup complete!"
```

---

### **Step 3: Test Without Documents**

```ruby
# Test 1: Basic chat (no documents)
result1 = PortfolioChatAgent.call(
  support_agent_id: agent.id,
  target: chat,
  user_message: "Hello, how are you?"
)

puts "\n=== TEST 1: No Documents ==="
puts result1[:ai_response]
# Should respond normally without document context
```

---

### **Step 4: Test With Documents**

```ruby
# Test 2: Chat with document context
result2 = PortfolioChatAgent.call(
  support_agent_id: agent.id,
  target: chat,
  user_message: "What was the Q3 revenue?",
  document_folder_path: "/tmp/test_documents"
)

puts "\n=== TEST 2: With Documents ==="
puts result2[:ai_response]
# Should respond: "According to financials.txt, Q3 revenue was $1.5M"
```

---

### **Step 5: Test Document Citation**

```ruby
# Test 3: Verify AI cites documents
result3 = PortfolioChatAgent.call(
  support_agent_id: agent.id,
  target: chat,
  user_message: "How many employees does the company have?",
  document_folder_path: "/tmp/test_documents"
)

puts "\n=== TEST 3: Document Citation ==="
puts result3[:ai_response]
# Should mention: "According to company_info.txt, the company has 50 employees"

# Check if response includes document name
if result3[:ai_response].downcase.include?('company_info')
  puts "✅ AI cited the document!"
else
  puts "❌ AI didn't cite the document"
end
```

---

### **Step 6: Test Information Not in Documents**

```ruby
# Test 4: Question about something not in documents
result4 = PortfolioChatAgent.call(
  support_agent_id: agent.id,
  target: chat,
  user_message: "What's the CEO's salary?",
  document_folder_path: "/tmp/test_documents"
)

puts "\n=== TEST 4: Info Not in Documents ==="
puts result4[:ai_response]
# Should say: "I don't see that information in the available documents"
```

---

### **Step 7: Test Memory with Documents**

```ruby
# Test 5: Memory works with document context
result5 = PortfolioChatAgent.call(
  support_agent_id: agent.id,
  target: chat,
  user_message: "What did I ask you about earlier?",
  document_folder_path: "/tmp/test_documents"
)

puts "\n=== TEST 5: Memory + Documents ==="
puts result5[:ai_response]
# Should reference previous questions (Q3 revenue, employees, CEO salary)

if result5[:ai_response].downcase.include?('revenue') || 
   result5[:ai_response].downcase.include?('employee')
  puts "✅ Memory works with documents!"
else
  puts "⚠️ Check memory"
end
```

---

## Complete Test Script

```ruby
# Copy-paste this entire block:

puts "🚀 PHASE 2: TESTING DOCUMENT FOLDER CONTEXT"
puts "="*60

# Setup (only if not already done)
company = Investor.first
analyst = User.first
report = AiPortfolioReport.create!(portfolio_company: company, analyst: analyst, status: 'draft', report_date: Date.today)
chat = report.ai_chat_sessions.create!(analyst: analyst)
agent = SupportAgent.create!(agent_type: 'PortfolioChatAgent', entity_id: analyst.entity_id, name: 'Chat', enabled: true)

folder = "/tmp/test_documents"

# Test 1: With documents
puts "\n📄 Test 1: Question about document content"
r1 = PortfolioChatAgent.call(support_agent_id: agent.id, target: chat, user_message: "What was Q3 revenue?", document_folder_path: folder)
puts r1[:ai_response]
test1_pass = r1[:ai_response].downcase.include?('1.5') || r1[:ai_response].downcase.include?('1.5m')
puts test1_pass ? "✅ PASS" : "❌ FAIL"

# Test 2: Document citation
puts "\n📝 Test 2: AI cites document"
r2 = PortfolioChatAgent.call(support_agent_id: agent.id, target: chat, user_message: "How many employees?", document_folder_path: folder)
puts r2[:ai_response]
test2_pass = r2[:ai_response].downcase.include?('50') && (r2[:ai_response].include?('company_info') || r2[:ai_response].include?('document'))
puts test2_pass ? "✅ PASS - Cited document" : "⚠️ CHECK - May not have cited"

# Test 3: Info not in docs
puts "\n❓ Test 3: Info not in documents"
r3 = PortfolioChatAgent.call(support_agent_id: agent.id, target: chat, user_message: "What's the CEO's age?", document_folder_path: folder)
puts r3[:ai_response]
test3_pass = r3[:ai_response].downcase.include?("don't") || r3[:ai_response].downcase.include?("not in") || r3[:ai_response].downcase.include?("doesn't")
puts test3_pass ? "✅ PASS - Acknowledged missing info" : "⚠️ CHECK"

# Test 4: Memory
puts "\n🧠 Test 4: Memory with documents"
r4 = PortfolioChatAgent.call(support_agent_id: agent.id, target: chat, user_message: "What did I ask about earlier?", document_folder_path: folder)
puts r4[:ai_response]
test4_pass = r4[:ai_response].downcase.include?('revenue') || r4[:ai_response].downcase.include?('employee')
puts test4_pass ? "✅ PASS - Memory works!" : "❌ FAIL - No memory"

# Summary
puts "\n" + "="*60
puts "📊 PHASE 2 TEST SUMMARY"
puts "Test 1 (Document content): #{test1_pass ? '✅' : '❌'}"
puts "Test 2 (Citation): #{test2_pass ? '✅' : '⚠️'}"
puts "Test 3 (Missing info): #{test3_pass ? '✅' : '⚠️'}"
puts "Test 4 (Memory): #{test4_pass ? '✅' : '❌'}"
puts "\nTotal messages: #{chat.ai_chat_messages.count}"
puts "="*60
```

---

## Document Limits

To avoid context window issues:

| Limit | Value | Why |
|-------|-------|-----|
| Max documents | 10 | Prevent context overflow |
| Max chars per document | 5,000 | Balance detail vs size |
| Max PDF pages | 20 | Extract reasonable amount |
| Supported extensions | 4 (.txt, .md, .pdf, .docx) | Common formats |

**Total estimated context:** ~50,000 chars = ~12,500 tokens (well within limits)

---

## Troubleshooting

### **Issue: "No documents loaded"**

```ruby
# Check if folder exists
Dir.exist?("/tmp/test_documents")  # Should be true

# Check if files exist
Dir.glob("/tmp/test_documents/*")  # Should show files

# Check agent logs
# Look for: "[PortfolioChatAgent] Loaded X documents into context"
```

### **Issue: "AI doesn't reference documents"**

```ruby
# Test if documents are being loaded
result = PortfolioChatAgent.call(
  support_agent_id: agent.id,
  target: chat,
  user_message: "What documents do you have access to?",
  document_folder_path: "/tmp/test_documents"
)
puts result[:ai_response]
# Should list: company_info.txt, financials.txt
```

### **Issue: "PDF extraction fails"**

```bash
# Ensure pdf-reader gem is installed
bundle list | grep pdf-reader

# If not installed:
bundle add pdf-reader
bundle install

# Restart console
exit
rails console
```

---

## Migration to S3 (Future)

Currently uses local file paths. When ready for S3:

### **Change 1: Update method signature**

```ruby
# Current (local)
def load_documents_from_folder(folder_path)
  Dir.glob(File.join(folder_path, "*"))
end

# Future (S3)
def load_documents_from_s3_folder(folder_id)
  s3_client = Aws::S3::Client.new
  objects = s3_client.list_objects_v2(
    bucket: ENV['AWS_S3_BUCKET'],
    prefix: "folders/#{folder_id}/"
  )
  # Process S3 objects...
end
```

### **Change 2: Update controller to pass folder_id**

```ruby
# Current
document_folder_path: "/local/path"

# Future
document_folder_id: params[:folder_id]
```

### **Change 3: Update step to use S3**

```ruby
# In agent
def load_document_context(ctx, **)
  folder_id = ctx[:document_folder_id]
  
  if folder_id.present?
    ctx[:documents_context] = load_documents_from_s3_folder(folder_id)
  end
end
```

**Minimal changes needed!** The core logic stays the same.

---

## Next Steps

### **Now:**
1. ✅ Test with local folder
2. ✅ Verify document loading works
3. ✅ Verify AI cites documents
4. ✅ Verify memory still works

### **Later:**
1. ⏳ Implement DOCX extraction
2. ⏳ Add S3 support
3. ⏳ Optimize document chunking
4. ⏳ Add document filtering (by type/relevance)

---

## Success Criteria

Phase 2 is complete when:

- ✅ AI loads documents from local folder
- ✅ AI references documents in answers
- ✅ AI cites document names
- ✅ AI says "not in documents" when appropriate
- ✅ Memory works with document context
- ✅ No context window errors

---

## Files Modified

```
app/packs/ai/support_agents/services/
└── portfolio_chat_agent.rb          ✅ Updated with folder context

Documentation:
└── PHASE2_FOLDER_CONTEXT.md         ✅ This file
```

---

**Ready to test Phase 2!** 🚀

Create test documents and run the test script!
