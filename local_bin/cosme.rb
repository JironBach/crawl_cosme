#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'open-uri' #URLにアクセスする為のライブラリ
require 'nokogiri' #Nokogiriライブラリ
require 'csv'
require 'openssl'
require 'fileutils'

SLEEP_DURATION = 1
goods = nil
kuchikomi = nil

def make_list
  target_urls = []
  target_urls << 'https://www.cosme.net/item/item_id/800/ranking'
  target_urls << 'https://www.cosme.net/item/item_id/800/ranking/page/1'
  #target_urls << 'https://www.cosme.net/item/item_id/800/ranking/page/2'
  #target_urls << 'https://www.cosme.net/item/item_id/800/ranking/page/3'
  #target_urls << 'https://www.cosme.net/item/item_id/800/ranking/page/4'
  target_urls
end

def get_html(url)
  charset = nil
  # windowsでssl系のエラーを回避するためにsslのverifyを無効に。
  # see http://final.hateblo.jp/entry/2016/08/28/194712
=begin  html = OpenURI.open_uri(url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}) do |f|
    charset = f.charset
    f.read #htmlを読み込み変数htmlにわたす。
  end
=end
  rows = []
  sleep(SLEEP_DURATION)
  html = Nokogiri::HTML(open(url))
  html.css('h4.item').each do |link|
    puts link.content
    goods = link.content
    puts link.css('a')[0][:href]
    row = goods_page(link.css('a')[0][:href], goods)
    rows << row.to_csv
  end
  rows
end

def goods_page(url, goods)
  charset = nil
  kuchikomi = nil
  maker = nil
  brand = nil
  # windowsでssl系のエラーを回避するためにsslのverifyを無効に。
  # see http://final.hateblo.jp/entry/2016/08/28/194712
  html = OpenURI.open_uri(url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}) do |f|
    charset = f.charset
    count_file = f.read
    count = count_file.match(%r{<span class="count cnt">(.*)</span>})[1]
    kuchikomi = count.to_i
    puts 'クチコミ数 : ' + kuchikomi.to_s
  end
  html = OpenURI.open_uri(url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}) do |f|
    charset = f.charset
    f.read #htmlを読み込み変数htmlにわたす。
  end
  sleep(SLEEP_DURATION)
  doc = Nokogiri::HTML.parse(html, nil, charset)
  doc.css("dl.brand-name.clearfix").each do |dl|
    brand = dl.at_css('dd a').text.strip
    puts 'ブランド : ' + brand
  end
  doc.css("dl.maker.clearfix").each do |dl|
    maker = dl.at_css('dd a').text.strip
    puts 'メーカー : ' + maker
  end
  address = ''
  tel = ''
  company_site = ''
  doc.css("dl.official-site.clearfix").each do |dl|
    site = dl.at_css('dd a')['href']
    puts '公式サイト : ' + site
    address, tel, company_site = get_company_site(site)
  end
  #[kuchikomi.to_s, goods, maker, brand, address, tel].map(&:strip)
  [kuchikomi.to_s, goods, maker, brand, address, tel, company_site]
end

def get_company_site(url)
  charset = nil
  f_read = nil
  html = OpenURI.open_uri(url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}) do |f|
    charset = f.charset
    f_read = f.read #htmlを読み込み変数htmlにわたす。
    f_read = f_read.force_encoding("utf-8")
  end
  address = nil
  tel = nil
  company_site = nil
  sleep(SLEEP_DURATION)
  doc = Nokogiri::HTML.parse(html, nil, charset)
  i = 0
  if f_read.index('会社')
    doc.css('a').each do |a|
      if a.text.strip.include?('会社')
        puts '会社概要 : ' + a[:href]
        company_site = a[:href]
        address, tel = get_tel_address(a[:href])
        break
      end
    end
  end
  sleep(SLEEP_DURATION)
  doc = Nokogiri::HTML.parse(html, nil, charset)
  if f_read.index('企業')
    doc.css('a').each do |a|
      if a.text.strip.include?('企業')
        puts '企業情報 : ' + a[:href]
        company_site = a[:href]
        address, tel = get_tel_address(a[:href])
        break
      end
    end
  end
  return address, tel, company_site
end

def get_tel_address(url)
  charset = nil
  f_read = nil
  html = nil
  begin
    html = OpenURI.open_uri(url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}) do |f|
      charset = f.charset
      f_read = f.read #htmlを読み込み変数htmlにわたす。
      f_read = f_read.force_encoding("utf-8")
    end
  rescue
    return
  end
  address = nil
  tel = nil
  sleep(SLEEP_DURATION)
  doc = Nokogiri::HTML.parse(html, nil, charset)
  if f_read.index('TEL')
    doc.css('th td').each do |td|
      puts 'TEL : ' + td.text.strip
      tel = td.text.strip
      break
    end
  end
  sleep(SLEEP_DURATION)
  doc = Nokogiri::HTML.parse(html, nil, charset)
  if f_read.index('住所')
    doc.css('th td').each do |td|
      puts '住所 : ' + td.text.strip
      address = td.text.strip unless address.nil?
      break
    end
  end
  sleep(SLEEP_DURATION)
  doc = Nokogiri::HTML.parse(html, nil, charset)
  if f_read.index('所在地')
    doc.css('th td').each do |td|
      puts '所在地 : ' + td.text.strip
      address = td.text.strip unless address.nil?
      break
    end
  end
  return address, tel
end

def get_rows(html)
  html.css('.normalResultsBox article section').map { |section|
    name = section.at_css('h4 a').content
    url = ORIGIN + section.at_css('h4 a')['href']

    paragraphs = section.css('p')

    address = paragraphs.find { |p| p.content.start_with?('住所') }.children[1].content
    tel = paragraphs.find { |p| p.content.start_with?('TEL') }.css('b').inner_html

    [name, url, address, tel].map(&:strip)
  }
end

FileUtils.rm("cosme_goods.csv") if File.exist?('cosme_goods.csv')
if File.exist?('cosme_goods.csv')
  write_mode = 'a'
else
  write_mode = 'w'
end
rows = []
make_list.each do |url|
  rows << get_html(url)
end
File.open('cosme_goods.csv', write_mode) { |fp|
  fp.puts(%w(kuchikomi goods maker brand address tel company_site).to_csv)
  rows = rows.flatten.sort {|a, b| b.to_i <=> a.to_i }.reverse
  puts rows.inspect
  rows.each do |row|
    fp.puts(row)
  end
}
