require "langchain"

class Textspace::Assistant::RagTool
  extend Langchain::ToolDefinition

  define_function :search, description: "キーワードを入力して、ECサイトの商品一覧データベースから近い商品を検索します" do
    property :query, type: "string", description: "検索対象の商品タイトル", required: true
  end

  attr_reader :textspace
  def initialize(textspace:)
    @textspace = textspace
  end

  def search(query:)
    pp "Running Assistant RAG"
    pp query
    # chunks = textspace.wise_search(query, 3)
    chunks = textspace.search(query, 3)[:chunks].flatten
    # pp chunks
    res = chunks.map(&:text)
    pp res
    res
  end
end
