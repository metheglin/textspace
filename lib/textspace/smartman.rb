require "openai"

class Textspace::Smartman
  attr_reader :textspace
  def initialize(textspace)
    @textspace = textspace
  end

  def ask(user_prompt)
    res_5w1h1e = ask_5w1h1e(user_prompt)
    res_what_meta = ask_what_meta(res_5w1h1e["what"])
    res_prioritized_keywords = ask_prioritized_keywords(res_5w1h1e, res_what_meta)
    chunks, selected_keywords = search_prioritized_keywords(res_prioritized_keywords, data_5w1h1e: res_5w1h1e, data_what_meta: res_what_meta)
    [
      chunks,
      {
        user_prompt: user_prompt,
        data_5w1h1e: res_5w1h1e,
        data_what_meta: res_what_meta,
        possible_keywords: res_prioritized_keywords,
        selected_keywords: selected_keywords,
      }
    ]
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
    res = ask_gpt4o(text, q, mode: :robotic)
    JSON.parse(res)
  end

  def ask_prioritized_keywords(data_5w1h1e, data_what_meta)
    q_what, q_who, q_where, q_when = data_5w1h1e.values_at("what", "who", "where", "when")
    clear_image, descriptive = data_what_meta.values_at("clear_image", "descriptive")

    keywords = {level1: [q_what], level2: nil, level3: nil, level4: nil}
    keywords = keywords.merge(level2: descriptive)

    keywords = if clear_image
      keywords
    else
      keywords.merge(
        level3: ->{
          res_breakdown = ask_what_breakdown([q_what, q_who].join(' '))
          res_breakdown["keywords"]
        },
        level4: ->{
          res_breakdown = ask_what_breakdown([q_what, q_who, q_where, q_when].join(' '))
          res_breakdown["keywords"]
        },
      )
    end
    keywords
  end

  def ask_what_meta(text)
    q = <<~EOS
      以下のECサイトの検索キーワードから以下カテゴリについて分析してJSONで出力せよ。
      - clear_image: 入力から具体的で特定的な商品（またはカテゴリ）がイメージできる場合はtrue、そうでない場合はfalse
      - descriptive: 入力が「記述的いいかえ」である場合は、それが指し示している具体的な商品名またはカテゴリ名を最大3つあげ、配列形式とする。そうでない場合はnull
    EOS
    res = ask_gpt4o(text, q, mode: :robotic)
    JSON.parse(res)
  end

  def ask_what_breakdown(text)
    q = <<~EOS
      以下のECサイトの検索キーワードから以下カテゴリについて分析してJSONで出力せよ。
      - keywords: ユーザがのぞんでいそうな具体的な商品キーワードの候補を最大5件あげ、配列形式とする
    EOS
    res = ask_gpt4o(text, q, mode: :creative)
    JSON.parse(res)
  end

  def search_prioritized_keywords(prioritized_keywords, data_5w1h1e:, data_what_meta:)
    clear_image, descriptive = data_what_meta.values_at("clear_image", "descriptive")
    level1, level2, level3, level4 = prioritized_keywords.values_at(:level1, :level2, :level3, :level4)
    [level4, level3, level2 ,level1].reduce([]) do |acc,kws|
      if kws.respond_to?(:call)
        kws = kws.call()
      end
      next acc unless kws
      next acc if kws.to_s.strip.empty?
      chunks = search_keywords(kws, data_5w1h1e: data_5w1h1e)
      chunks = chunks.select{|chunk, sim| sim > 0}.sort_by{|chunk, sim| sim}.reverse
      pp chunks
      if chunks.length > 0
        max_chunk, max_sim = chunks.first
        acc = [
          ((acc[0] || []) + chunks).uniq{|ch,sim| ch.id},
          (acc[1] || []) + kws,
        ]
        if clear_image
          pp "it has clear_image kws=#{kws} max_sim=#{max_sim}"
          return acc if max_sim >= 0.4
        else
          pp "it doesn't have clear_image kws=#{kws} length=#{chunks.length}"
          return acc if chunks.length >= 8
        end
      end
      acc
    end
  end

  def search_keywords(keywords, data_5w1h1e:)
    pp keywords
    q_what, q_who, q_when, q_where, q_why, q_how, q_exclude = data_5w1h1e.values_at("what", "who", "when", "where", "why", "how", "exclude")
    res_chunks = textspace.search(keywords, 3).flatten(1)
    ask_screening(res_chunks, q_what, q_how, q_exclude)
  end

  def ask_screening(chunks, q_what, q_how, q_exclude)
    q_main = [q_what, q_how].join(' ').strip
    pp "screening 'main' #{q_main}"
    res_screening_main = ask_screening_main(chunks, q_main)
    pp res_screening_main
    chunks = chunks.map{|ch,sim|
      screen_result = res_screening_main["items"].find{|item| item["id"] == ch.id}
      if screen_result and score = screen_result["score"]
        sim_scored = sim - ((5.0-score.to_f) * 0.1)
        [ch, sim_scored]
      else
        [ch, sim]
      end
    }
    
    if q_exclude
      pp "screening 'exclude' #{q_exclude}"
      res_screening_exclude = ask_screening_exclude(chunks, q_exclude)
      pp res_screening_exclude
      chunks = chunks.map{|ch,sim|
        screen_result = res_screening_exclude["items"].find{|item| item["id"] == ch.id}
        if screen_result and score = screen_result["score"]
          # sim_scored = sim - score.to_f * 0.3
          sim_scored = sim - ((3.0-score.to_f) * 0.3)
          [ch, sim_scored]
        else
          [ch, sim]
        end
      }
    end
    chunks
  end

  def ask_screening_main(chunks, q_main)
    q = <<~EOS
      以下のECサイトの商品それぞれについて以下カテゴリについて分析してJSONで出力せよ。
      - items: 商品ごとの配列
        - id: 入力された商品idを指定すること
        - score: 
          この商品textがコンテキスト「#{q_main}」に基づいているかを1-5のスケールで評価。
          5: 完全にコンテキストに基づいている
          4: ほぼコンテキストに基づいている
          3: 部分的にコンテキストに基づいている  
          2: あまりコンテキストに基づいていない
          1: コンテキストを無視している
    EOS
    text = chunks.map{|ch,sim| ch.to_h.to_json}.join("\n")
    res = ask_gpt4o(text, q, mode: :robotic)
    JSON.parse(res)
  end

  def ask_screening_exclude(chunks, q_exclude)
    q = <<~EOS
      以下のECサイトの商品それぞれについて以下カテゴリについて分析してJSONで出力せよ。
      - items: 商品ごとの配列
        - id: 入力された商品idを指定すること
        - score: 
          この商品textがコンテキスト「#{q_exclude}」に基づいているかを1-3のスケールで評価。
          3: 完全にコンテキストに基づいている
          2: 部分的にコンテキストに基づいている  
          1: コンテキストを無視している
    EOS
    text = chunks.map{|ch,sim| ch.to_h.to_json}.join("\n")
    res = ask_gpt4o(text, q, mode: :robotic)
    JSON.parse(res)
  end

  def ask_gpt4o(user_prompt, system_prompt, mode: :creative)
    mode_list = {
      creative: {model: :"gpt-5-mini", temperature: 1.0, top_p: 1.0},
      robotic: {model: :"gpt-5-nano", temperature: 1.0, top_p: 1.0},
    }
    mode_params = mode_list[mode] || {}

    openai = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    res = openai.chat(
      parameters: {
        messages: [
          {role: "system", content: system_prompt},
          {role: "user", content: user_prompt}
        ],
        model: :"gpt-4o",
        response_format: {type: "json_object"},
        **mode_params
      }
    )
    res.dig("choices", 0, "message", "content")
  end
end
