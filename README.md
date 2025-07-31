# Textspace

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/textspace`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'textspace'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install textspace

## Usage

```
OPENAI_API_KEY=xxx bundle exec irb
```

```ruby
# require "textspace"
require "csv"

model = "openai/text-embedding-3-small"

csv = CSV.new(File.open("tmp/sample_products.csv"))
texts = csv.map{|r| r[0]}

ts = Textspace.new(model: model, texts: texts)
ts.estimation
ts.build_index!
# ts.ssindex
# ts.ssindex.save("tmp/embeddings.bin")


# 結婚記念日のプレゼント
# 小学校の入学祝い
# 安眠グッズ
# この夏の暑さを乗り切る
res = ts.fetch_embeddings_openai(["安眠グッズ"])
query = res[:embeddings]
ts.index_search(query, 2)
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/textspace.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
