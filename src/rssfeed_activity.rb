require 'ruboto/widget'
require 'ruboto/util/stack'
require 'ruboto/util/toast'
require 'rss'

java_import "android.content.Intent"
java_import "android.net.Uri"
java_import "android.media.MediaPlayer"
java_import "android.media.AudioManager"

ruboto_import_widgets :LinearLayout, :TextView, :ListView

class RssfeedActivity
  def onCreate(bundle)
    super
    @activity = self
    set_title 'RSSFeeds'
    @list = []
    @url = 'http://allrls.net/feed/atom'
    get_feed(@url)
    self.content_view = linear_layout orientation: :vertical, gravity: :top do
      @status = text_view id: 42, text: 'Activity created...'
      @list_view = list_view id: 43, list: @list,
        on_item_click_listener: proc {|av, v, pos, i| get_links(v.text.to_s)}
    end

  rescue Exception
    puts "Exception creating activity: #{$!}"
    puts $!.backtrace.join("\n")
  end

  def onCreateOptionsMenu(menu)
    menu.add('Allrls.net').set_on_menu_item_click_listener do |menu_item|
      @url = 'http://allrls.net/feed/atom'
      get_feed(@url)
      true
    end
  
    mi = menu.add('Sceper.ws')
    mi.set_on_menu_item_click_listener do |menu_item|
      @url = 'http://sceper.ws/feed/atom'
      get_feed(@url)
      true
    end
    true # Display the menu.
  end
  
  def onResume
    super
#    @list_view.on_item_click_listener = proc {|av, v, pos, i| get_links(v.text.to_s)}
#    get_feed(@url)
    @activity
    true
  end

  def get_feed(url)
    # io operations need to happen in a thread
    Thread.with_large_stack do
      begin
        run_on_ui_thread { @status.text = "Getting rss feed from #{url}" }
        @subjects = {}
        run_on_ui_thread { @list_view.adapter.clear; @list_view.on_item_click_listener = proc {|av, v, pos, i| get_links(v.text.to_s, @subjects)} }
        rss = RSS::Parser.parse(url)
        rss.entries.each do |item|
          @subjects[item.title.content] = []
          item.links.each do |link|
            @subjects[item.title.content].push(link.href) if link.type.start_with?('video')
          end
        end
        run_on_ui_thread { @list_view.adapter.add_all @subjects.keys }
        run_on_ui_thread { @status.text = 'List updated' }
      rescue Exception
        msg = "#{$!.message}\n#{$!.backtrace.join("\n")}"
        run_on_ui_thread { @status.text = "Thread: Exception: #{msg}" }
      end
    end
  end

  def get_links(title, hash, &block)
    ruboto_import_widgets :ListView
    @@links = hash.fetch(title)
    @@title = title
    @link_activity = self
    # need a new activity so we can resume to the links
    start_ruboto_activity do
      def onCreate(bundle)
        super
        setTitle @@title
        setContentView(list_view(list: @@links, on_item_click_listener: proc { |av, v, pos, i| open_video_url(v.text.to_s) }))
      end

      def onResume
        super
        @link_activity
        true
      end

      # pass to new activity
      def open_video_url(link)
        toast 'Opening url with ACTION_VIEW and URI'
        vid_intent = Intent.new(Intent::ACTION_VIEW, Uri.parse(link))
        startActivity(vid_intent)
      end

      # try to play with mediaplayer
      def open_video_mp(link)
        mp = MediaPlayer.new
        mp.setAudioStreamType(AudioManager::STREAM_MUSIC)
        mp.setDataSource(link)
        mp.prepare
        mp.start
      end

      # try in a webview
      def setup_webview(link)
        android::webkit::WebView.web_contents_debugging_enabled = true
        self.content_view = Ruboto::R::layout::webview
        @webview = self.find_view_by_id Ruboto::R::id::webview
        set = @webview.settings
        set.use_wide_view_port = true
        set.load_with_overview_mode = true
        set.loads_images_automatically = true
        set.java_script_enabled = true
        set.support_zoom = true            # enable zoom
        set.built_in_zoom_controls = true  # includes pinch gesture
        set.display_zoom_controls = false  # do not display +/- zoom controls
        @webview.load_url link
      end      


    end
  end
end
