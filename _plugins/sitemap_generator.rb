# _plugins/sitemap_generator.rb
require 'fileutils'
require 'date'
require 'cgi'

module Jekyll
  class SitemapGenerator < Generator
    safe true
    priority :lowest

    def generate(site)
      base_url = (site.config['url'] || '').chomp('/')
      base_path = (site.config['baseurl'] || '').chomp('/')
      site_root_url = "#{base_url}#{base_path}"

      entries = []

      # 1. Static Pages
      site.pages.each do |page|
        next if skip_item?(page)
        entries << build_entry(page, site, site_root_url)
      end

      # 2. Posts
      site.posts.docs.each do |post|
        next if skip_item?(post)
        entries << build_entry(post, site, site_root_url)
      end

      # 3. Collections (विद आउटपुट और साइटमैप वैलिडेशन)
      site.collections.each do |label, collection|
        next if label == 'posts'

        # अगर पूरे कलेक्शन का output: false हो या sitemap: false सेट हो तो स्किप करें
        next if skip_collection?(collection, site, label)

        collection.docs.each do |doc|
          next if skip_item?(doc)
          entries << build_entry(doc, site, site_root_url)
        end
      end

      xml_content = generate_xml(entries.compact)
      site.pages << SitemapPage.new(site, site.source, '', 'sitemap.xml', xml_content)
    end

    private

    # पूरे कलेक्शन को चेक करने का लॉजिक
    def skip_collection?(collection, site, label)
      # Jekyll में collection.write? चेक करता है कि output: true है या नहीं
      return true if collection.respond_to?(:write?) && !collection.write?

      # _config.yml में कलेक्शन मेटाडेटा चेक करें
      meta = collection.metadata || {}
      config_entry = site.config.dig('collections', label) || {}

      return true if meta['output'] == false || config_entry['output'] == false
      return true if meta['sitemap'] == false || config_entry['sitemap'] == false

      false
    end

    # किसी सिंगल पेज/डॉक्यूमेंट को चेक करने का लॉजिक
    def skip_item?(item)
      return true if item.data['sitemap'] == false
      return true if item.data['published'] == false
      return true if item.data['output'] == false

      # अगर URL उपलब्ध न हो
      return true if item.url.nil? || item.url.empty?

      # गैर-HTML फाइल्स को बाहर रखें
      return true if item.output_ext != '.html' && !item.url.end_with?('/')

      false
    end

    def resolve_file_path(item, site)
      return nil unless item.respond_to?(:path) && item.path
      return item.path if File.exist?(item.path)

      full_path = File.join(site.source, item.path)
      return full_path if File.exist?(full_path)

      collections_dir = site.config['collections_dir'] || ''
      if !collections_dir.empty?
        coll_path = File.join(site.source, collections_dir, item.path)
        return coll_path if File.exist?(coll_path)
      end

      nil
    end

    def get_git_lastmod(file_path)
      return nil unless file_path && File.exist?(file_path)
      date_str = `git log -1 --format="%cI" -- "#{file_path}" 2>/dev/null`.strip
      return nil if date_str.empty?

      DateTime.parse(date_str).strftime('%Y-%m-%d')
    rescue StandardError
      nil
    end

    def build_entry(item, site, base_url)
      url = "#{base_url}#{item.url}"
      lastmod = nil

      if item.data['last_modified_at']
        lastmod = parse_date(item.data['last_modified_at'])
      elsif item.data['date']
        lastmod = parse_date(item.data['date'])
      else
        file_path = resolve_file_path(item, site)
        if file_path
          # Vercel एनवायरनमेंट या लोकल Git रिपोजिटरी से Git Commit Date
          if ENV['VERCEL'] == 'true' || File.directory?(File.join(site.source, '.git'))
            lastmod = get_git_lastmod(file_path)
          end

          # फॉलबैक: GitHub Pages या मिसिंग Git लॉग के लिए फाइल सिस्टम mtime
          if lastmod.nil?
            lastmod = File.mtime(file_path).strftime('%Y-%m-%d') rescue Time.now.strftime('%Y-%m-%d')
          end
        else
          lastmod = Time.now.strftime('%Y-%m-%d')
        end
      end

      { loc: url, lastmod: lastmod }
    end

    def parse_date(date_val)
      return Time.now.strftime('%Y-%m-%d') if date_val.nil?

      case date_val
      when Time, Date, DateTime
        date_val.strftime('%Y-%m-%d')
      when String
        begin
          DateTime.parse(date_val).strftime('%Y-%m-%d')
        rescue ArgumentError
          Time.now.strftime('%Y-%m-%d')
        end
      else
        Time.now.strftime('%Y-%m-%d')
      end
    end

    def generate_xml(entries)
      xml = %(<?xml version="1.0" encoding="UTF-8"?>\n)
      xml << %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n)

      entries.uniq { |e| e[:loc] }.each do |entry|
        xml << "  <url>\n"
        xml << "    <loc>#{CGI.escapeHTML(entry[:loc])}</loc>\n"
        xml << "    <lastmod>#{entry[:lastmod]}</lastmod>\n"
        xml << "  </url>\n"
      end

      xml << %(</urlset>)
      xml
    end
  end

  class SitemapPage < Page
    def initialize(site, base, dir, name, content)
      @site = site
      @base = base
      @dir  = dir
      @name = name
      self.process(name)
      self.content = content
      self.data = {
        'layout' => nil,
        'sitemap' => false
      }
    end
  end
end