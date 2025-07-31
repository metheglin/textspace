require "tiktoken_ruby"

class Textspace::OpenAI < Textspace::Provider
  attr_reader :model
  def initialize(model:)
    @model = model
  end

  def provider
    "openai"
  end

  def name
    model
  end

  def get_estimation(texts)
    encoder = Tiktoken.encoding_for_model(model)
    estimated_token_count = texts.sum {|text| encoder.encode(text).size}
    price = price_per_1k_tokens(model)
    estimated_cost_usd = (estimated_token_count / 1000.0) * price
    {
      estimated_token_count: estimated_token_count,
      estimated_cost_usd: estimated_cost_usd,
    }
  end

  def dimensions
    case model
    when "text-embedding-3-small"
      1536
    when "text-embedding-3-large"
      3072
    when "text-embedding-ada-002"
      0.0 # TODO:
    else
      # Return 0.0 for unknown models or raise an error
      0.0
    end
  end

  private

  # Pricing data from OpenAI (as of July 2024)
  def price_per_1k_tokens(model)
    case model
    when "text-embedding-3-small"
      0.00002 # $0.00002 / 1K tokens
    when "text-embedding-3-large"
      0.00013 # $0.00013 / 1K tokens
    when "text-embedding-ada-002"
      0.00010 # $0.00010 / 1K tokens
    else
      # Return 0.0 for unknown models or raise an error
      0.0
    end
  end
end
