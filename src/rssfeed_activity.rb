require 'ruboto/widget'
require 'ruboto/util/stack'
require 'ruboto/util/toast'
require 'rss'

java_import "android.content.Intent"
java_import "android.net.Uri"

ruboto_import_widgets :LinearLayout, :TextView, :ListView

class RssfeedActivity
  def onCreate(bundle)
    super
    set_title 'Allrls.net'
    @list = []
    @url = 'http://allrls.net/feed/atom'
    self.content_view = linear_layout orientation: :vertical, gravity: :top do
      @status = text_view id: 42, text: 'Activity created...'
      @list_view = list_view id: 43, list: @list
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
    mi.set_icon $package.R::drawable::get_ruboto_core
    mi.set_on_menu_item_click_listener do |menu_item|
      @url = 'http://sceper.ws/feed/atom'
      get_feed(@url)
      true
    end
    true # Display the menu.
  end
  
  def onResume
    super
    @status.text = 'Resuming activity...'
    @list_view.adapter.clear
    @list_view.on_item_click_listener = proc {|av, v, pos, i| get_links(v.text.to_s)}
    get_feed(@url)
    @status.text = 'Resume...OK'
  end

  def get_feed(url)
    Thread.with_large_stack do
      begin
        run_on_ui_thread { @status.text = 'Started update feed...' }
        @subjects = {}
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

  def get_links(title)
    @status.text = 'Links Loaded'
    links = @subjects.fetch(title)
    run_on_ui_thread { @list_view.adapter.clear; @list_view.adapter.add_all links; @list_view.on_item_click_listener = proc { |av, v, pos, i| self.open_video_url(v.text.to_s) } }
  end

  def open_video_url(link)
    toast 'opening url with browser, not really video files'
    vid_intent = Intent.new(Intent::ACTION_VIEW, Uri.parse(link))
    startActivity(vid_intent)
  end

end
