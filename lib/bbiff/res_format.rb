require 'cgi'
require_relative 'bbs_reader'

class Integer
  def em
    ' ' * (self*2)
  end

  def en
    ' ' * self
  end
end

def render_name(name, email)
  if email.empty?
    name
  else
    name
  end
end

def render_resno(no)
  no.to_s
end

def render_date(t)
  weekday = [*'日月火水木金土'.each_char]
  delta = Time.now - t

  case delta
  when 0...1
    "たった今"
  when 1...60
    "#{delta.to_i}秒前"
  when 60...3600
    "#{(delta / 60).to_i}分前"
  when 3600...(24 * 3600)
    "#{(delta / 3600).to_i}時間前"
  else
    "%d/%d/%d(%s) %02d:%02d:%02d" % [t.year, t.month, t.day, weekday[t.wday], t.hour, t.min, t.sec]
  end
end

# 日付を絶対時間で表示
def render_date_absolute(t)
  weekday = [*'日月火水木金土'.each_char]
  delta = Time.now - t
  "%d/%d/%d(%s) %02d:%02d:%02d" % [t.year, t.month, t.day, weekday[t.wday], t.hour, t.min, t.sec]
end

def indent(n, text)
  text.each_line.map { |line| n.en + line }.join
end

def render_body(body)
  # 改行タグ
  unescaped = CGI.unescapeHTML(body.gsub(/<br>/i, "\n"))
  # その他のhtmlタグ
  unescaped.gsub!(%r{<.*?>},"")
  # 安価文字を青色
  unescaped.gsub!(%r{(>>[0-9]+)}, "\e[34m\\1\e[0m")
  indent(4, unescaped) + "\n"
end

# 書き込みを表示
def render_post(post)
  "\n#{render_resno post.no}：#{green(render_name post.name, post.mail)}：#{cyan(render_date_absolute post.date)}\n" \
  "#{render_body post.body}"
end

# 指定したコマンドが存在するか？
def exist_command? command
  system("hash",command) ? true : false
rescue => e
  puts yellow(e.message)
  false
end

# 書き込みを読み上げ
def say_post post
  formatter = Bbiff::SayResFormatter
  # system("say","#{Shellwords.escape(formatter.format(post))}","-r","1")
  if @voice
    # 音声オプションを指定して再生
    system("say","#{formatter.format(post)}","-r","1","-v",@voice)
  else
    # デフォルトの音声オプションで再生
    system("say","#{formatter.format(post)}","-r","1")
  end
rescue => e
  puts yellow(e.message)
end

def notify_post post
  formatter = Bbiff::NotifyResFormatter
  TerminalNotifier.notify(render_body(post.body), title: formatter.title(post), appIcon: formatter.app_icon_path)
end

# 色付出力用文字列
def green str
  "\e[32m#{str}\e[0m"
end
def cyan str
  "\e[36m#{str}\e[0m"
end
def yellow str
  "\e[33m#{str}\e[0m"
end
def blue str
  "\e[34m#{str}\e[0m"
end
def red str
  "\e[31m#{str}\e[0m"
end
def magenta str
  "\e[35m#{str}\e[0m"
end


# posts = Bbs::C板.new('game', 48538).thread(1416739363).posts(1..Float::INFINITY)
# puts posts.map(&method(:render_post)).join("\n\n")
