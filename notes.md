that's a lot of stuff to cover - i think we need to distill it. was thinking I'd start with a breakdown of where time is spent when you run something like "ri TCPServer"

1. your shell layer (maybe get a quick show of hands of who uses bash vs zsh?) I think it will be heavily skewed zsh these days due to it being default on mac. This is where every cli tool starts, and "ri" either resolves to a function or to the PATH. If you are using rbenv to manage your rubies, like I and many of you are, your shell will find ~/.rbenv/shims/ri (quick, <5ms)

2. the rbenv layer. The ri shim is a bash script that exec's itself with "rbenv exec ri", which is where it finds the ruby entrypoint to ri under your current ruby. Version managers vary, but getting this perfectly right across various OS's ruby versions, overlapping package managers, system ruby, etc without being able to use a language like ruby is non-trivial. This spawns dozens of subshells, walks directories, all via shell script.  (slowest, 150ms)

3. the rubygems stub
We are now in ruby, but still not at the "real" ri yet. Every executable installed via rubygems has one of these "
require 'rubygems'

Gem.use_gemdeps

version = ">= 0.a"

str = ARGV.first
if str
  str = str.b[/\A_(.*)_\z/, 1]
  if str and Gem::Version.correct?(str)
    version = str
    ARGV.shift
  end
end

if Gem.respond_to?(:activate_and_load_bin_path)
  Gem.activate_and_load_bin_path('rdoc', 'ri', version)
else
  load Gem.activate_bin_path('rdoc', 'ri', version)
end"

This loads rubygems, loads dependencies of ri, and then .... never actually runs the real kamal via its shebang ruby - at the bottom, it just loads it directly as a library file. Notice that we are executing the shebang ruby here, and its no longer usr/bin/env ruby -its been fully resolved to the realpath of it.
 Up until the last line, very slow, around 80ms
 
And then load is finally called on the activated bin path, and we can now say ready


And a process like this one happens for every standard issue ruby CLI tool you use. So what if, we could just always be ready? 

Could we run all but the last layer ahead of time, and keep it hot & ready?

Turns out this kind of thing has a history in ruby, and some of you know exactly what I'm talking about, some of you don't and use it daily, and well, some of you don't and probably disabled it years ago after reading some stack overflow post on why your rails server wasn't starting. ( shows stack overflow screenshots with dozens of upvotes saying DISABLE_SPRING=1"

I'm talking of course, about our buddy who peaked in high school, and one who I still personally call a friend, Mr. rails/spring




