require 'prism'

TERM_RE = /_term/

def classify(code)
  return :text if code.lines.all? { |l| l.strip.empty? || l.start_with?("#") }
  clean = code.gsub(/---/, "")
  r = Prism.parse(clean)
  return :code if r.errors.empty?
  has_term = r.errors.any? { |e| e.type.to_s.match?(TERM_RE) }
  if has_term
    (1..5).each do |n|
      return :incomplete_code if Prism.parse(clean + ("\nend" * n)).errors.empty?
    end
  end
  :text
end

def flush(buf, mode)
  return if buf.empty?
  text = buf.join("\n\n")
  # Convert definition lists (term\n:   desc) to term\n  desc
  # so glow doesn't render them with the 🠶 character
  text.gsub!(/^:   /m, "  ")
  if mode == :code
    puts "```ruby"
    puts text
    puts "```"
  else
    puts text
  end
  puts
end

buf = []
mode = nil
accumulating = false

ARGF.to_io.each("\n\n", chomp: true) do |paragraph|
  paragraph.chomp!
  next if paragraph.strip.empty?

  if accumulating
    buf << paragraph
    combined_cls = classify(buf.join("\n"))
    if combined_cls == :code
      flush(buf, :code)
      buf = []
      mode = nil
      accumulating = false
    elsif combined_cls == :incomplete_code
      # keep accumulating
    else
      # new paragraph broke it — flush accumulated as code, reprocess current
      current = buf.pop
      flush(buf, :code)
      buf = []
      accumulating = false

      cls = classify(current)
      if cls == :incomplete_code
        accumulating = true
        mode = :code
        buf = [current]
      else
        mode = cls == :code ? :code : :text
        buf = [current]
      end
    end
  else
    cls = classify(paragraph)
    if cls == :incomplete_code
      if mode && mode != :code
        flush(buf, mode)
        buf = []
      end
      mode = :code
      buf << paragraph
      accumulating = true
    else
      cur = cls == :code ? :code : :text
      if mode && mode != cur
        flush(buf, mode)
        buf = []
      end
      mode = cur
      buf << paragraph
    end
  end
end

flush(buf, mode)
