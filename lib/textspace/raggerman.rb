require "openai"

class Textspace::Raggerman

  attr_reader :kw
  def initialize(kw)
    @kw = kw
  end

  def answer1_0(text)
    @answer1_0 ||= begin
      prompt = <<~EOS
        以下のキーワードが否定表現を含む場合は否定された部分の文のみを、そうでない場合は0を返せ

        「#{text}」
      EOS
      ask_gpt4o(prompt)
    end
  end

  def answer1_1(text)
    @answer1_1 ||= begin
      prompt = <<~EOS
        以下のECサイトの検索キーワードにおいて、具体的な商品（またはカテゴリ）が１つだけイメージできる場合は1、そうでない場合は2、番号のみをこたえよ。

        「#{text}」
      EOS
      ask_gpt4o(prompt)
    end
  end

  def answer1_2(text)
    @answer1_2 ||= begin
      prompt = <<~EOS
        以下のキーワードが記述的いいかえである場合は1、そうでない場合は2、番号のみをこたえよ。

        「#{text}」
      EOS
      ask_gpt4o(prompt)
    end
  end

  def answer1_3(text)
    @answer1_3 ||= begin
      prompt = <<~EOS
        以下のキーワードが指し示している具体的な商品名またはカテゴリ名を３つまで挙げて。,区切りでワードのみをこたえること

        「#{text}」
      EOS
      ask_gpt4o(prompt)
    end
  end

  def answer2_1(text)
    @answer2_1 ||= begin
      # prompt = <<~EOS
      #   以下のECサイトの検索キーワードからユーザがのぞんでいそうな具体的な商品キーワードの候補を最大10件あげよ。,区切りでワードのみをこたえること。
      #   また、検索キーワードが「10以上」「2020以降」など数値の演算をともなう文言を含む場合は数値演算表現を含まない表現（例: 10,11,12、2024年,2025年）に言い換えること

      #   「#{text}」
      # EOS
      prompt = <<~EOS
        以下のECサイトの検索キーワードからユーザがのぞんでいそうな具体的な商品キーワードの候補を最大5件あげよ。,区切りでワードのみをこたえること。

        「#{text}」
      EOS
      ask_gpt4o(prompt)
    end
  end

  def keywords
    @keywords ||= begin
      negation = answer1_0(kw)
      _keywords = case answer1_1(kw)
      when '1' # １つだけイメージできる
        case answer1_2(kw)
        when '1' # 記述的いいかえ
          answer1_3(kw)
        when '2' # 記述的いいかえでない
          kw
        else
          raise "Invalid answer for answer1_2:"
        end
      when '2' # 1つにイメージできない
        answer2_1(kw)
      else
        raise "Invalid answer for answer1_1:"
      end

      {
        keywords: _keywords,
        negation: negation,
      }
    end
  end

  # TODO
  def filter_negation
  end


  # def answer1
  #   @answer1 ||= begin
  #     prompt1 = <<~EOS
  #       以下のECサイトの検索キーワードにおいて、
  #       具体的な商品（またはカテゴリ）が１つだけイメージできる場合は(1)、
  #       そうでない場合は(2)。
  #       (1)の場合、それが記述的いいかえである場合は(2-0)。
  #       (1)の場合、キーワードに否定形などの論理的思考をともなう文言があれば(2-1)。
  #       (1)の場合、キーワードに「10以上」「2020以降」など数値の演算をともなう文言があれば(2-2)。
  #       キーワードがどれに分類されるか番号のみをこたえよ。

  #       「#{kw}」
  #     EOS
  #     ask_gpt4o(prompt1)
  #   end
  # end

  # def answer2
  #   @answer2 ||= begin
  #     if answer1 == '(1)' or answer1 == '1'
  #       # ほしいものが明確
  #       kw
  #     elsif answer1 == '(2)' or answer1 == '2'
  #       # ほしいものを探してる
  #       prompt2 = <<~EOS
  #         以下のECサイトの検索キーワードからユーザがのぞんでいそうな具体的な商品キーワードの候補を10件あげて。カンマ区切りでワードのみをこたえること

  #         「#{kw}」
  #       EOS
  #       ask_gpt4o(prompt2)
  #     elsif answer1 == '(2-0)' or answer1 == '2-0'
  #       # ほしいものの名前を探ってる
  #       prompt2 = <<~EOS
  #         以下のECサイトの検索キーワードが指し示している具体的な商品名またはカテゴリ名を３つまで挙げて。カンマ区切りでワードのみをこたえること

  #         「#{kw}」
  #       EOS
  #       ask_gpt4o(prompt2)
  #     elsif answer1 == '(2-1)' or answer1 == '2-1'
  #       # ほしいものが明確だが否定形を含むため肯定形に変換
  #       prompt2 = <<~EOS
  #         以下のECサイトの検索キーワードを否定形を含まない表現で言い換えて。ワードのみをこたえること

  #         「#{kw}」
  #       EOS
  #       ask_gpt4o(prompt2)
  #     elsif answer1 == '(2-2)' or answer1 == '2-2'
  #       # ほしいものが明確だが数値演算を含むため検索可能なように変換
  #       prompt2 = <<~EOS
  #         以下のECサイトの検索キーワードを数値演算表現を含まない表現で言い換えて。ワードのみをこたえること。例: 10以上→10,11,12、 2024年以降→2024年,2025年

  #         「#{kw}」
  #       EOS
  #       ask_gpt4o(prompt2)
  #     else
  #       # FALL BACK
  #       raise "FALL BACK NEEDED HERE: #{answer1}"
  #     end
  #   end
  # end

  def ask_gpt4o(prompt)
    openai = OpenAI::Client.new
    res = openai.chat.completions.create(
      messages: [{role: "user", content: prompt}],
      model: :"gpt-4o"
    )
    res[:choices][0][:message][:content]
  end
end
