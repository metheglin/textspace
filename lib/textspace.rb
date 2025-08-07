require "delegate"
require "openai"
require "faiss"
require "langchain"

class Textspace < DelegateClass(Array)

  VERSION = "0.1.0"

  class Chunk < Struct.new(:id, :text, keyword_init: true)
  end

  attr_reader :model, :texts, :chunks
  attr_reader :tokens_count
  attr_accessor :ssindex

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
    client = ::OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    res = client.embeddings(
      parameters: {
        model: model.name,
        input: strs
      }
    )
    embeddings = res["data"].map{|d| d["embedding"]}
    total_tokens = res["usage"]["total_tokens"]
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

  def search(query, k)
    query = Array(query)
    res = fetch_embeddings_openai(query)
    embedding_query = res[:embeddings]
    index_search(embedding_query, k)
  end

  def wise_search(query, k)
    raggerman = Textspace::Raggerman.new(query)
    keywords, nagation = raggerman.keywords.values_at(:keywords, :negation)
    pp "keywords", keywords
    res = search(keywords, k)
    sim_values = res[:d].to_a.flatten.map.with_index{|val,idx| [val,idx]}.sort_by{|val, idx| val}.reverse
    sim_indice = sim_values.first(k*3).map{|v,idx| idx}
    indice = res[:i].to_a.flatten.values_at(*sim_indice)
    chunks = self.values_at(*indice)
    res_filter = raggerman.filter_negation(chunks: chunks, original_keyword: query)
    pp res_filter
    ids_excluding = res_filter.split(',').map(&:strip)
    chunks.reject{|chunk| ids_excluding.include?(chunk.id)}.first(k)
  end

  def assistant_search(query, k)
    llm = Langchain::LLM::OpenAI.new(
      api_key: ENV["OPENAI_API_KEY"],
    )
    rag_tool = Textspace::AssistantRagTool.new(textspace: self)
    assistant = Langchain::Assistant.new(
      llm: llm,
      instructions: "あなたはECサイトのユーザがのぞんでいる商品を探すアシスタントです。ユーザが入力するキーワードをもとにおのぞみの商品を考え、RAGデータベースへベクトル検索を実行してください。",
      tools: [rag_tool]
    )
    assistant.add_message_and_run!(content: query)
  end

  private
    def build_chunk(obj)
      obj.is_a?(Chunk) ? obj : Chunk.new(id: SecureRandom.hex(4), text: obj)
    end
end

require_relative "./textspace/provider"
require_relative "./textspace/raggerman"
require_relative "./textspace/assistant_rag_tool"
