require 'uri'
require 'natto'

module Bbiff
  module SayResFormatter
    class << self

      def format post
        @body = post.body.clone
        unescape_body
        replace_uri
        replace_w
        omit(140)
        replace_aa

        # "レス%<no>d。%<body>s" % {
        #   no: post.no,
        #   body: @body
        # }

        normalizer = Mecab::Normalizer.new
        # normalizer.register_articulate("居玉", "いぎょく")
        normalized_text = normalizer.normalize_from_text(@body)

        "レス%<no>d。：%<body>s" % {
          no: post.no,
          body: normalized_text
        }
      end

      private
      # HTMLをエスケープ
      def unescape_body
        @body = CGI.unescapeHTML(@body.gsub(/<br>/i, "。\n")) + "\n"
        @body.gsub!(%r{<.*?>},"")
        @body.gsub!(%r{>>([0-9]+)}, "レス\\1へのレス。")
      end

      # URLを変換
      def replace_uri
        @body.gsub!(%r{h?ttps?://[\w/:%#\$&\?~\.=\+\-]+}, " URL ")
      end

      # 文末ｗをワラに
      def replace_w
        @body.gsub!(%r{ｗ+}, "ワラ")
      end

      # 長文を省略
      def omit(size)
        @body = @body[0..size] + "。\n以下略" if @body.size > size
      end

      # アスキーアートならアスキーアートに変換
      def replace_aa
        # AA省略
        @body = "アスキーアート" if @body =~ %r{＼|∪|∩|⌒|从|;;;|:::|\,\,\,|'''}
      end

    end
  end
end


module Mecab
  class << self
    # @param [String] text
    def parse(text)
      natto_result = ::Natto::MeCab.new.parse(text)
      natto_result.lines.map { |line|
        line.chop!
        next if line == "EOS"
        result = Result.new
        result.instance_eval { parse_line(line) }
        result
      }.compact
    end
  end

  class Result
    # origin: 原文, part: 品詞, yomi: カタカナ読み
    attr_reader :origin, :part, :class1, :class2, :class3, :katsuyou_kei, :katsuyou_kata, :origin_kana, :yomi, :articulate

    def inspect
      "<Mecab::Result: #{origin} #{part} #{class1} #{class2} #{class3} #{katsuyou_kei} #{katsuyou_kata} #{origin_kana} #{yomi} #{articulate}>"
    end

    # 英語か
    def english?
      !!(origin =~ /\A[\wＡ-Ｚａ-ｚ]+\Z/)
    end

    # 長音(伸ばし棒)か
    def macron?
      !!(origin =~ /[〜ー]/)
    end

    # 全角カンマか
    def comma_ja?
      origin == "、"
    end

    # 句点か
    def period_ja?
      origin == "。"
    end

    private

    # @param [String] line
    def parse_line(line)
      @origin, *other = line.split(/\t/)
      @part, @class1, @class2, @class3, @katsuyou_kei, @katsuyou_kata, @origin_kana, @yomi, @articulate = other.first.split(',')
    end
  end

  class Normalizer
    def initialize
      @dict = {}
    end

    # @param [String] origin
    # @param [String] articulate
    def register_articulate(origin, articulate)
      @dict[origin] = articulate
    end

    # @param [Array(Mecab::Result)] results
    def normalize(results)
      text = ""
      skip = false
      (results + [Result.new]).each_cons(2) do |result, next_result|
        if skip
          skip = false
          next
        end

        if result.english?
          # 英文の時
          text += result.origin.tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
          text += " " if next_result.english?
        elsif result.macron? and next_result.comma_ja?
          text += result.origin
          text += "。"
          skip = true
        elsif result.class1 == "係助詞" && result.origin == "は"
          # 接続詞の は を ワ に置換する
          text += "ワ"
        else
          text += result.origin
        end
        text += "\\"
      end
      text[-1] = "。" if text[-1] == "、"
      text += "。" unless text =~ /。\Z/
      text.gsub!(/。/, "。\n")

      @dict.each do |origin, articulate|
        text.gsub!(origin, " #{articulate} ")
      end
      text
    end

    # @param [String] text
    def normalize_from_text(text)
      _text = text.clone
      _text.gsub!(/[。、]{3,}/, "…")
      _text.gsub!(/。?\n{2,}/, "。")
      _text.gsub!(/、?\n/, "、")
      _text.gsub!("　", "。")

      results = Mecab.parse(_text)
      normalize(results)
    end
  end
end
