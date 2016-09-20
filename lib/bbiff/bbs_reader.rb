require 'net/http'
require 'uri'

module Bbs
# スレッド情報を保持するクラス
class C板
  attr_reader :スレ一覧URL, :カテゴリ, :掲示板番号

  def initialize(カテゴリ, 掲示板番号)
    @カテゴリ = カテゴリ
    @掲示板番号 = 掲示板番号
    @設定URL = URI.parse( "http://jbbs.shitaraba.net/bbs/api/setting.cgi/#{カテゴリ}/#{掲示板番号}/" )
    @スレ一覧URL = URI.parse( "http://jbbs.shitaraba.net/#{カテゴリ}/#{掲示板番号}/subject.txt" )
  end

  def dat_url(スレッド番号)
    return URI.parse("http://jbbs.shitaraba.net/bbs/rawmode.cgi/#{@カテゴリ}/#{@掲示板番号}/#{スレッド番号}/")
  end

  def 設定
    r = ダウンロード(@設定URL)
    return 設定をパーズする(r.force_encoding("EUC-JP").encode("UTF-8"))
  end

  def スレ一覧
    r = ダウンロード(@スレ一覧URL)
    return r.force_encoding("EUC-JP").encode("utf-8", :invalid => :replace, :undef => :replace)
  end

  def dat(スレッド番号)
    url = dat_url(スレッド番号)
    r = ダウンロード(url)
    return r.force_encoding("EUC-JP").encode("UTF-8")
  end

  def thread(スレッド番号)
    threads.find { |t| t.id == スレッド番号 }
  end

  def threads
    スレ一覧.each_line.map do |line|
      fail 'スレ一覧のフォーマットが変です' unless line =~ /^(\d+)\.cgi,(.+?)\((\d+)\)$/
      id, title, last = $1.to_i, $2, $3.to_i
      Thread.new(self, id, title, last)
    end
  end

  def ダウンロード(url)
    応答 = Net::HTTP.start(url.host, url.port) { |http|
      http.get(url.path)
    }
    return 応答.body
  end

  private

  def 設定をパーズする(文字列)
    文字列.each_line.map { |line|
      line.chomp.split(/=/, 2)
    }.to_h
  end
end

class Post
  attr_reader :no, :name, :mail, :body

  def self.from_line(line)
    no, name, mail, date, body, = line.split('<>', 6)
    Post.new(no, name, mail, date, body)
  end

  def initialize(no, name, mail, date, body)
    @no = no.to_i
    @name = name
    @mail = mail
    @date = date
    @body = body
  end

  def date
    str2time(@date)
  end

  def to_s
    [no, name, mail, @date, body, '', ''].join('<>')
  end

  private

  def str2time(str)
    if str =~ %r{^(\d{4})/(\d{2})/(\d{2})\(.\) (\d{2}):(\d{2}):(\d{2})$}
      y, mon, d, h, min, sec = [$1, $2, $3, $4, $5, $6].map(&:to_i)
      Time.new(y, mon, d, h, min, sec)
    else
      fail ArgumentError
    end
  end
end

class Thread
  attr_reader :id, :title, :last, :board, :url

  def initialize(board, id, title, last = 1)
    @board = board
    @id = id
    @title = title
    @last = last
    @url = "http://jbbs.shitaraba.net/bbs/read.cgi/#{@board.カテゴリ}/#{@board.掲示板番号}/#{id}/"
  end

  def dat_url
    @board.dat_url(@id)
  end

  def posts(range)
    fail ArgumentError unless range.is_a? Range
    dat_for_range(range).each_line.map do |line|
      Post.from_line(line.chomp).tap do |post|
        # ついでに last を更新
        @last = [post.no, last].max
      end
    end
  end

  def dat_for_range(range)
    if range.last == Float::INFINITY
      query = "#{range.first}-"
    else
      query = "#{range.first}-#{range.last}"
    end
    url = URI(dat_url + query)
    @board.ダウンロード(url).force_encoding("EUC-JP").encode("UTF-8")
  end
end

end # Module
# include Bbs
# 自板 = C板.new("game", 48538)
# # puts 自板.設定
# # puts 自板.スレ一覧
# t =  自板.thread(1416739363)

# p t.posts(900..950)
