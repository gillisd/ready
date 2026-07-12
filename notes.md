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


---

## "but what about bootsnap?" (prep for the reflexive objection)

Someone will raise bootsnap. It's not a threat, it's a gift — the honest answer shows we understand the layers better than the objection does. Bootsnap and ready operate on DISJOINT layers and don't actually compete.

What bootsnap does (two things):
1. load-path cache — memoizes `require 'x'` -> absolute path so you skip the $LOAD_PATH walk on every require.
2. compile cache — stores RubyVM::InstructionSequence bytecode so a require skips parse+compile. (also caches YAML/JSON compile, immaterial here.)

The ordering is the whole game. Bootsnap is itself a gem, and it hooks rubygems' already-patched Kernel#require. So rubygems must be fully loaded (and bundler/setup run first, to populate $LOAD_PATH) before `bootsnap/setup` can layer on top. Its interception begins strictly AFTER rubygems + bundler are up. It cannot, even in principle, accelerate its own prerequisites.

Map that onto our layers (numbers from a real run of `ronin`):
- shell (~5ms) + rbenv (~40ms): not in ruby yet -> bootsnap can't touch it.
- `require "rubygems"` (~45ms): loads BEFORE bootsnap exists -> can't touch it.
- `Gem.activate_bin_path` — spec resolution + dependency activation (~343ms, the biggest layer): can't touch it.
- tool + its deps' code getting required (~82ms): partially yes, this is bootsnap's home.

So bootsnap is blind to the two biggest layers. And the biggest one for a precise reason worth saying out loud: the ISeq cache saves parse+compile, NOT execution. Activation is rubygems EXECUTING — scanning specifications/, building spec stubs, resolving the graph. There's no bytecode to cache; it's work, not compilation. Bootsnap only shaves the tail, and only the compile slice of the tail.

And bootsnap is project-centered; ready is global. This isn't just cultural — there's no mechanism. Bootsnap's cache is anchored to a project (tmp/cache/bootsnap) and armed in that app's boot.rb. A globally-installed colorls / ronin / ri has no boot.rb you own. Your only lever is jamming RUBYOPT=-rbootsnap/setup into every ruby invocation — and even then you (a) still pay rubygems + activation in full, (b) pay bootsnap's setup on every call, (c) have a global cache with no project to scope it. You basically can't apply it here, usefully.

Synthesis line for the talk: bootsnap shrinks the TAIL (compiling/resolving lots of code) inside a process that's already past rubygems and activation — it shines when a big app boots the same huge tree repeatedly in dev. ready eliminates the HEAD (shell, rbenv, rubygems load, dependency activation) by keeping a process hot past all of it. They're complementary, not competing — a ready server could even use bootsnap internally to speed its own one-time warmup. For the per-invocation tax on a global CLI, bootsnap structurally cannot reach where the time is. ready is aimed exactly there.




