# 通知用フォーマットに変換
module Bbiff
  module NotifyResFormatter
    class << self

      # terminal-notifier用フォーマット
      def format post
      end

      def title post
        "#{post.no}: #{post.name}"
      end

      def app_icon_path
        "#{File.expand_path(File.dirname($0))}/../assets/images/app_icon.png"
      end

      private

    end
  end
end
