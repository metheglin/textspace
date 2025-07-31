class Textspace::Provider
  def self.parse(model)
    provider, model_name = model.split('/')
    if provider == 'openai'
      Textspace::OpenAI.new(model: model_name)
    else
      raise "Unsupported provider #{provider}"
    end
  end
end

require_relative "./provider/openai"
