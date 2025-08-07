require "openai"

class Textspace::Smartman
  # attr_reader :prompt
  # def initialize(prompt)
  #   @prompt = prompt
  # end

  def ask(user_prompt)
    res_5w1h1e = ask_5w1h1e(user_prompt)
    ask_what(res_5w1h1e)
  end

  def ask_5w1h1e(text)
    q = <<~EOS
      ECサイトで商品を探しているユーザの入力について、以下カテゴリについて分析してJSONで出力せよ。不明なものは null とすること。
      - what: 何をのぞんでいるか
      - who: 誰のための商品か
      - when: いつその商品が必要か
      - where: どこでまたはどこの商品が必要か
      - why: なぜその商品が必要か
      - how: 金額や重さや配送方法など、どのような条件の商品が必要か
      - exclude: 除外や否定表現を含む場合、必ずその情報を含めること
    EOS
    res = ask_gpt4o(text, q)
    JSON.parse(res)
  end

  def ask_what(data_5w1h1e)
    q_what, q_who, q_where, q_when = data_5w1h1e.values_at("what", "who", "where", "when")
    res_meta = ask_what_meta(q_what)
    keywords = if res_meta["clear_image"]
      if res_meta["descriptive"]
        pp "clear_image: false, descriptive: true"
        res_meta["descriptive"]
      else
        pp "clear_image: true, descriptive: false"
        [q_what]
      end
    else
      pp "clear_image: false, descriptive: false"
      res_breakdown_highcontext = ask_what_breakdown([q_what, q_who, q_where, q_when].join(' '))
      res_breakdown_highcontext["keywords"]

      # res_breakdown_core = ask_what_breakdown([q_what, q_who].join(' '))
      # res_breakdown_core["keywords"]
    end
    keywords
  end

  def ask_what_meta(text)
    q = <<~EOS
      以下のECサイトの検索キーワードから以下カテゴリについて分析してJSONで出力せよ。
      - clear_image: 入力から具体的で特定的な商品（またはカテゴリ）がイメージできる場合はtrue、そうでない場合はfalse
      - descriptive: 入力が「記述的いいかえ」である場合は、それが指し示している具体的な商品名またはカテゴリ名を最大3つあげ、配列形式とする。そうでない場合はnull
    EOS
    res = ask_gpt4o(text, q)
    JSON.parse(res)
  end

  def ask_what_breakdown(text)
    q = <<~EOS
      以下のECサイトの検索キーワードから以下カテゴリについて分析してJSONで出力せよ。
      - keywords: ユーザがのぞんでいそうな具体的な商品キーワードの候補を最大5件あげ、配列形式とする
    EOS
    res = ask_gpt4o(text, q)
    JSON.parse(res)
  end

  def ask_gpt4o(user_prompt, system_prompt)
    openai = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    res = openai.chat(
      parameters: {
        messages: [
          {role: "system", content: system_prompt},
          {role: "user", content: user_prompt}
        ],
        model: :"gpt-4o",
        response_format: {type: "json_object"},
      }
    )
    res.dig("choices", 0, "message", "content")
  end
end
