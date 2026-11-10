════════════════════════════════════════════════════════════════
                 DEEP THOUGHT — Local Language Models
════════════════════════════════════════════════════════════════

Hello again. It's Zim.

This folder holds a few language models: programs you can talk
to in plain words, like the chatbots that ran on the internet.
These ones run on your own computer.  No internet needed.

Before you start, one thing you should know about them.

They are not me.  I'm a library.  When you look something up in
my zim/ folder, you get the article someone wrote, with sources.
A model gives you its best guess, in confident sentences, and
sometimes the guess is wrong.  It can make up a medicine dose or
a citation that sounds perfect and isn't real.

So use them the way you'd use a well-read friend: to explain
something, to help you figure out what to look up, to get you
unstuck.  Then check anything that matters against the library.
Doses, wiring, food safety, anything you'd regret getting wrong.

────────────────────────────────────────────────────────────────
HOW TO START ONE
────────────────────────────────────────────────────────────────

Windows:      double-click start-ai.bat
Mac / Linux:  open a terminal in this folder and run
                  sh start-ai.sh

I'll check how much memory your computer has, pick a model that
fits, and start it.  The first start takes a minute or two while
I unpack the program onto your computer.

When it says "listening on", open this address in any web browser:

    http://127.0.0.1:8081

Type a question and press Enter.  You can also attach a photo
(a plant, a rash, a broken part) to the models marked "reads
images" below.

To stop it, close the window or press Ctrl+C.

To pick a model yourself:

    sh start-ai.sh --list            (Windows: start-ai.bat --list)
    sh start-ai.sh gemma-4-e4b       (Windows: start-ai.bat gemma-4-e4b)

────────────────────────────────────────────────────────────────
THE MODELS
────────────────────────────────────────────────────────────────

Bigger models are smarter and slower.  "Memory" means the RAM in
your computer, not the space on a disk.

  gemma-4-e2b       6 GB   Gemma 4 E2B, by Google.  Reads images.
                           Small and quick.  Old laptops, phones,
                           a Raspberry Pi 5.

  gemma-4-e4b       8 GB   Gemma 4 E4B, by Google.  Reads images.
                           The one most laptops will get.

  gpt-oss-20b      16 GB   gpt-oss 20B, by OpenAI.  Text only.
                           Good at working through a problem
                           step by step.

  gemma-4-26b-a4b  24 GB   Gemma 4 26B-A4B, by Google.  Reads
                           images.  Big, but only part of it works
                           on each word, so it's still quick.

  gemma-4-31b      32 GB   Gemma 4 31B, by Google.  Reads images.
                           Very slow unless your computer has a
                           big graphics card.  Pick it by name.

  qwen3.8-27b      32 GB   Qwen3.8 27B, by Alibaba.  Reads images.
                           Also slow without a graphics card.
                           Pick it by name.

A good trick with the two big ones: ask both.  They were trained
by different people on different data.  If they disagree, that's
your sign to go read the actual article.

────────────────────────────────────────────────────────────────
USING IT WITH THE LIBRARY
────────────────────────────────────────────────────────────────

You can run the library and a model at the same time.  Start
kiwix-serve the way my main README.txt describes (it uses port
8080) and the model (port 8081), then keep both open in two
browser tabs.  Ask the model what to look for.  Look it up.

────────────────────────────────────────────────────────────────
WHAT'S IN THIS FOLDER
────────────────────────────────────────────────────────────────

start-ai.bat     Windows launcher (it runs start-ai.ps1)
start-ai.sh      Mac and Linux launcher
models.tsv       The list the launchers read
llama.cpp/       The program that runs the models, for Windows,
                 Mac, and Linux.  It's free software (MIT license)
                 from github.com/ggml-org/llama.cpp
<model>/         One folder per model.  The .gguf file is the
                 model.  A file with "mmproj" in its name is the
                 part that lets it see images.

If it won't start:

  - Not enough memory: pick a smaller model by name.
  - Linux says a library is missing: these builds were made on
    Ubuntu and may not run on very old systems.  Try a newer
    Linux from my isos/ folder.
  - A graphics card is causing trouble: set ARK_AI_CPU=1 to use
    the processor only.  (Windows: run "set ARK_AI_CPU=1" in a
    command prompt, then start-ai.bat from that same window.)
  - Something else is using port 8081: set ARK_AI_PORT to
    another number, like 8082.

────────────────────────────────────────────────────────────────
LICENSES
────────────────────────────────────────────────────────────────

All six models are released under the Apache License 2.0
(LICENSE-Apache-2.0.txt).  gpt-oss also comes with OpenAI's
usage policy, and Qwen with its own copy of the license; those
are in their folders.  These are the makers' original releases,
not modified versions.  Everything here was checked against the
makers' published checksums when this drive was built.

They were frozen when I was.  Like me, they don't know what's
happened since.
