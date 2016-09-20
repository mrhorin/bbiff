require 'cgi'
require_relative 'bbs_reader'

class Fixnum
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

def indent(n, text)
  text.each_line.map { |line| n.en + line }.join
end

def render_body(body)
  unescaped = CGI.unescapeHTML(body.gsub(/<br>/i, "\n"))
  indent(4, unescaped) + "\n"
end

# 書き込みを表示
def render_post(post)
  "\n#{render_resno post.no}：#{green(render_name post.name, post.mail)}：#{cyan(render_date_absolute post.date)}\n" \
  "#{render_body post.body}"
end


# posts = Bbs::C板.new('game', 48538).thread(1416739363).posts(1..Float::INFINITY)
# puts posts.map(&method(:render_post)).join("\n\n")
