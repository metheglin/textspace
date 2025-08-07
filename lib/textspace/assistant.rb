require "langchain"

class Textspace::Assistant
  DEFAULT_INSTRUCTIONS = <<~EOS
    あなたはECサイトのユーザがのぞんでいる商品を探すアシスタントです。ユーザが入力するキーワードをもとにおのぞみの商品を考え、RAGデータベースへベクトル検索を実行してください。
    検索クエリを考える際、次のことに注意しなさい。

    - ユーザ入力が「記述的言い換え」の場合は、それが指し示している具体的な商品名またはカテゴリ名を最大3個考えて検索クエリとすること
    - クエリに含まれる固有季節語がコモディティ偏らせる場合は弱めること
  EOS
  attr_reader :assistant
  def initialize(textspace:, instructions: nil)
    llm = Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"])
    rag_tool = Textspace::Assistant::RagTool.new(textspace: textspace)
    @assistant = Langchain::Assistant.new(
      llm: llm,
      instructions: instructions || DEFAULT_INSTRUCTIONS,
      tools: [rag_tool]
    )
  end

  def search(query, k)
    assistant.add_message_and_run!(content: query)
  end
end

require_relative "./assistant/rag_tool"
