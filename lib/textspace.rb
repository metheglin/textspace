require "delegate"
require "openai"
require "faiss"

class Textspace < DelegateClass(Array)

  VERSION = "0.1.0"

  class Chunk < Struct.new(:id, :text, keyword_init: true)
  end

  attr_reader :model, :texts, :chunks
  attr_reader :tokens_count
  attr_reader :ssindex

  def initialize(model:, texts: [])
    @model = model.is_a?(Textspace::Provider) ?
      model :
      Textspace::Provider.parse(model)
    super(texts.map{|text| build_chunk(text)})
  end

  def <<(obj)
    super(build_chunk(obj)); self
  end

  def push(*objs)
    super(*objs.map{|obj| build_chunk(obj)})
  end

  def concat(objs)
    super(objs.map{|obj| build_chunk(obj)})
  end

  # TODO:
  # def insert(index, *objs)
  # end

  def []=(obj)
    super(build_chunk(obj))
  end
  
  def texts
    self.map(&:text)
  end

  def estimation
    model.get_estimation(texts)
  end

  def build_index!
    case model.provider
    when "openai"
      res = fetch_embeddings_openai(texts)
      @tokens_count = res[:total_tokens]
      @ssindex = begin
        idx = Faiss::IndexFlatIP.new(model.dimensions)
        idx.add(res[:embeddings])
        idx
      end
      res
    else
      raise "Unsupported provider: #{model.provider}"
    end
  end

  def fetch_embeddings_openai(strs)
    client = ::OpenAI::Client.new
    res = client.embeddings.create(
      model: model.name,
      input: strs
    )
    embeddings = res[:data].map{|d| d[:embedding]}
    total_tokens = res[:usage][:total_tokens]
    {
      embeddings: embeddings,
      total_tokens: total_tokens,
    }
  end

  def index_search(query, k)
    return nil unless @ssindex
    d, i = @ssindex.search(query, k)
    chunks = i.to_a.map{|indice| self.values_at(*indice)}
    {
      chunks: chunks,
      d: d,
      i: i,
    }
  end

  private
    def build_chunk(obj)
      obj.is_a?(Chunk) ? obj : Chunk.new(text: obj)
    end
end

require_relative "./textspace/provider"
