require 'unicode/display_width'
require 'io/console'

module Bbiff
  class Executable
    # 正規表現パターン
    PATTERN = {
      THREAD: %r{\Ah?ttp://jbbs.shitaraba.net/bbs/read.cgi/(\w+)/(\d+)/(\d+)/?\z}
    }.freeze

    def initialize
      @settings  = Settings.new
      @out = Bbiff::LineIndicator.new
    end

    def main
      # ヘルプオプション
      if ARGV.include?('-h') || ARGV.include?('--help')
        usage
        exit 1
      end
      # スレッド選択オプション
      ts_option_exist = false
      if ARGV.include?('-ts')
        thread = thread_select
        ARGV.delete("-ts")
        @settings.current['thread_url'] = thread.url
        ts_option_exist = true
      end

      # 通知オプション
      notify_option_exist = ARGV.include?('-n')
      notify_command_exist = exist_command?("terminal-notifier")
      @notify = notify_option_exist && notify_command_exist
      ARGV.delete("-n") if notify_option_exist

      # 読み上げオプション
      say_option_exist = ARGV.include?('-s')
      say_command_exist = exist_command?("say")
      @say = say_option_exist && say_command_exist
      @voice = nil
      # sayコマンドのボイスオプション
      if say_option_exist
        idx = ARGV.index("-s") + 1
        voice = ARGV[idx]
        if voice && voice[0...4] != "http"
          @voice = voice
          ARGV.delete(voice)
        end
      end
      ARGV.delete("-s") if say_option_exist

      # URLを取得
      if ARGV.size < 1 && !@settings.current['thread_url']
        # 引数がなくて,スレッドURLが保存されてない時
        raise UsageError
      elsif ARGV.size < 1
        # 引数がオプション以外なくて, スレッドURLが存在する時
        url = @settings.current['thread_url']
      else
        url = ARGV[0]

        if url =~ PATTERN[:THREAD]
          @settings.current['thread_url'] = url
        else
          puts yellow("URLが変です")
          usage
          exit 1
        end
      end

      # URLから板情報を抽出
      if url =~ PATTERN[:THREAD]
        # [板カテゴリ, 板ID]
        ita = [$1, $2.to_i]
        # スレID
        sure = $3.to_i
      end

      bbs = Bbs::C板.new(*ita)
      # スレッド
      thread = bbs.thread(sure) unless ts_option_exist
      # 読み込みを開始するレス番
      start_no = ARGV[1] ? ARGV[1].to_i : thread.last + 1

      puts magenta("#{thread.board.設定['BBS_TITLE']} − #{thread.title}(#{thread.last})")
      puts magenta("    #{@settings.current['thread_url']}")
      # 読み込み開始
      start_polling(thread, start_no)
    ensure
      # 設定を保存
      @settings.save
    end

    # スレ一覧から選択したBbs::Threadを返す
    def thread_select
      current_thread_url = @settings.current["thread_url"]
      if current_thread_url =~ PATTERN[:THREAD]
        # [板カテゴリ, 板ID]
        ita = [$1, $2.to_i]
      else
        puts yellow("保存されているURLが変です")
        usage
        exit 1
      end
      bbs = Bbs::C板.new(*ita)
      threads = bbs.threads

      threads.each_with_index do |t,i|
        puts "#{i}: #{t.title}(#{t.last})"
      end
      puts green("\nスレッド番号を入力してEnter")

      # スレッド番号を入力
      no = input_console.to_i
      if threads[no].class == Bbs::Thread
        return threads[no]
      else
        puts yellow("存在しないスレッド番号です")
        usage
        exit 1
      end
    end

    # ユーザーからの入力値を受け取って返す
    def input_console
      # ユーザーの入力値
      input = ""
      @out.set_line "入力: #{input}"
      # キー入力
      while (key = STDIN.getch) != "\r"
        break if key == "\C-c"
        input += key if key =~ /[0-9]/
        @out.set_line "入力: #{input}"
      end
      @out.clear
      return input
    end

    # 読み込み開始
    def start_polling(thread, start_no)
      # 更新間隔(秒)
      delay = @settings.current['delay_seconds']
      # 掲示板設定
      board_settings = thread.board.設定

      # スレスト番号
      thread_stop = (board_settings['BBS_THREAD_STOP'] || '1000').to_i
      # 未読の書き込みを格納する配列
      posts = Array.new
      # スレ更新停止フラグ
      stop = false

      # 何秒待ったか
      j = 0
      # 更新処理
      update_thread = Thread.new do
        loop do
          # 新着レスをpostsに追加
          thread.posts(parse_range("#{start_no}-")).each do |post|
            # 読み込み開始スレ番を更新
            start_no = thread.last + 1
            posts.push post
          end
          # スレスト処理
          if start_no > thread_stop
            stop = true
            break
          end
          # 更新秒待つ
          delay.times do |i|
            j = i + 1
            sleep 1
          end
        end
      end

      # 出力処理
      out_thread = Thread.new do
        loop do
          # 出力したレス数
          size = 0
          posts.each_with_index do |post,idx|
            @out.clear if idx.to_i == 0
            # レスを表示
            puts render_post(post)
            # レスを通知
            notify_post(post) if @notify
            # レスを読み上げる
            say_post(post) if @say
            size += 1
            sleep 1
          end
          @out.set_line "#{thread.title}(#{thread.last}) 待機中 [#{'.'*j}#{' '*(delay - j)}]"
          sleep 1
          # 出力したレス数ぶん先頭から削除
          posts.shift size
          # スレストしていたら終了
          if stop
            @out.puts yellow("スレッドストップ")
            exit
          end
        end
      end

      update_thread.join
      out_thread.join
    rescue Interrupt
      STDERR.puts yellow("\nユーザー割り込みにより停止")
    rescue => e
      sleep 3
      @out.clear
      begin
        Thread.kill update_thread
      rescue
      end
      begin
        Thread.kill out_thread
      rescue
      end

      start_polling(thread, start_no)
    end

    def parse_range(str)
      if str == "all"
        1..Float::INFINITY
      elsif str =~ /^\d+$/
        str.to_i..str.to_i
      elsif str =~ /^\d+-$/
        str.to_i..Float::INFINITY
      elsif str =~ /^(\d+)-(\d+)$/
        $1.to_i..$2.to_i
      else
        fail ArgumentError
      end
    end

    def usage
      STDERR.puts "Usage: bbiff [http://jbbs.shitaraba.net/bbs/read.cgi/CATEGORY/BOARD_ID/THREAD_ID/] [START_NUMBER]"

      STDERR.puts <<-"EOD"

  Options:
    -s [voice]  sayコマンドが存在する場合はレス読み上げ。
                voiceでボイスエンジンを指定,指定がない場合はデフォルト。
    -n          terminal-notifierコマンドが存在する場合はレスを通知。
    -ts         保存済みのスレの板からスレッドを選択してスレを開く。

  Bbiff version #{Bbiff::VERSION}
  Copyright © 2016 Yoteichi
      EOD
    end

  end
end
