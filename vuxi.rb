# = Vuxi -- a minimalist static Wiki compiler
#
# Copyright (C) 2010 Christian Neukirchen <purl.org/net/chneukirchen>
# Licensed under the terms of the MIT license.

require 'time'
$: << "vendor"
require 'bluecloth'; require 'rubypants'; require 'htemplate'
BlueCloth::EmptyElementSuffix.replace(">")

Dir.mkdir("html")  rescue true

def File.write(name, content)
  File.open(name, "wb") { |out| out << content }
  puts name
end

def dep(dst, *srcs)
  yield dst  unless srcs.all? { |src|
               (File.mtime(src) < File.mtime(dst) rescue false) }
end

def parse(f)
  head, body = File.read(f).split("\n\n", 2)  rescue (return nil)
  entry = {:body => body, :id => File.basename(f, ".page"), :file => f}
  head.scan(/(\w+): *(.*)/) { entry[$1.downcase.to_sym] = $2 }
  entry[:date] = entry[:date] ? Time.parse(entry[:date]) : File.mtime(f)
  entry[:updated] = entry[:updated] ? Time.parse(entry[:updated]) : File.mtime(f)
  entry
end

Entry = Hash.new { |h, k| h[k] = parse k }
ENTRIES = Dir.glob("pages/*.page").map { |x| Entry[x] }.
                                      sort_by { |f| f[:updated] }.reverse
Entry.values.each { |v| Entry[v[:id]] = v }

class WikiLinks < String
  def to_html
    # ~single~ or multiple~words are links.
    gsub(/(\b~?(?:\w+~)+\w+~?\b|\B~\w+~\B)/) {
      %Q{<a href="#{$&.delete('~').downcase}">#{$&.tr('~', ' ').strip}</a>}
    }
  end
end

def format(e)
  [WikiLinks, BlueCloth, RubyPants].inject(e[:body]) { |a,e| e.new(a).to_html }
end

def template(template, data)
  HTemplate.new(File.read(template), template).expand(data)
end

recent = ENTRIES.first(10)

Entry["index"][:recent] = recent

ENTRIES.each { |entry|
  dep "html/#{entry[:id]}", entry[:file], "template/page.ht" do |dst|
    File.write(dst, template("template/page.ht", entry))
  end
}
File.write("html/index.html", template("template/page.ht", Entry["index"]))
File.write("html/index.atom", template("template/atom.ht",
                                       :entries => recent, :time => Time.now))
File.write("html/all", template("template/all.ht", ENTRIES))

system "rsync -r data/ html"
