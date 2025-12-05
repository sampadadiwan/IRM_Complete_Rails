module AgentTools
  class WebSearchTool
    # Searches the web using DuckDuckGo's Instant Answer API
    # @param query [String] search query
    # @return [Hash] search results with abstract, related topics, and sources
    def self.search(query)
      Rails.logger.info "[WebSearchTool] Searching for: #{query}"
      
      response = HTTParty.get(
        "https://api.duckduckgo.com/",
        query: { 
          q: query, 
          format: 'json',
          no_html: 1,
          skip_disambig: 1
        },
        timeout: 10
      )
      
      parse_results(response)
    rescue StandardError => e
      Rails.logger.error "[WebSearchTool] Search failed: #{e.message}"
      { error: e.message }
    end

    private

    # Parses DuckDuckGo API response
    # @param response [HTTParty::Response] API response
    # @return [Hash] parsed results
    def self.parse_results(response)
      data = JSON.parse(response.body)
      
      {
        abstract: data['Abstract'],
        abstract_text: data['AbstractText'],
        abstract_source: data['AbstractSource'],
        abstract_url: data['AbstractURL'],
        related_topics: extract_related_topics(data),
        sources: extract_sources(data)
      }
    rescue JSON::ParserError => e
      Rails.logger.error "[WebSearchTool] JSON parse error: #{e.message}"
      { error: "Failed to parse search results" }
    end

    # Extracts related topics from search results
    # @param data [Hash] parsed JSON data
    # @return [Array<String>] related topic texts
    def self.extract_related_topics(data)
      return [] unless data['RelatedTopics'].present?
      
      topics = []
      data['RelatedTopics'].first(5).each do |topic|
        if topic['Text'].present?
          topics << topic['Text']
        elsif topic['Topics'].present?
          # Handle nested topics
          topic['Topics'].first(3).each do |subtopic|
            topics << subtopic['Text'] if subtopic['Text'].present?
          end
        end
      end
      
      topics.compact.uniq
    end

    # Extracts source URLs from search results
    # @param data [Hash] parsed JSON data
    # @return [Array<String>] source URLs
    def self.extract_sources(data)
      sources = []
      
      sources << data['AbstractURL'] if data['AbstractURL'].present?
      
      data['RelatedTopics']&.first(3)&.each do |topic|
        sources << topic['FirstURL'] if topic['FirstURL'].present?
        
        if topic['Topics'].present?
          topic['Topics'].first(2).each do |subtopic|
            sources << subtopic['FirstURL'] if subtopic['FirstURL'].present?
          end
        end
      end
      
      sources.compact.uniq
    end
  end
end
