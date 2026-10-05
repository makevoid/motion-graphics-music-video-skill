# Motion graphics music video plugin

<a href=".claude-plugin/icon.svg"><img src=".claude-plugin/icon.svg" width="128" height="128" alt="Orange glass chat bubble with a timeline play button and music note"></a>

A Claude Code plugin for creating high quality motion graphics videos from just a music track and a prompt - This skill is made to be used with  Opus 5.5

---

It includes Image generation and editing with GPT 2.5 Sunburts xhigh for generating characters and potentially other graphics, MiniMax H3 to animate the characters and the graphics in a with a greenscreen background and other tools that are helpful to isolate audio for lip-sync and SFX creation - all of these are done via FAL.ai API via video/audio adapters - For the animation Nodejs with P5JS is used, local Python is used for  analysis/cutouts/audio mixing and Swift Core has powerful and fast Image VFX (video effects).

This is a very powerful toolkit that will generate videos like the ones below with a relatively low budget (~30$ of Fal AI credits and around 3M Tokens of Opus 5.5 for a ~3m long song / video).

Follow the quick start below, then supply a song and creative prompt. The agent researches, writes the character/scene plan for approval, then generates in reviewed sub-agent waves of 2 → 3–4 → 4–8 → 6–10 repeatedly. This let you shorten the generation time substantially still giving enough context to Opus if the generations are going better or worse so that Opus can try to tweak / rework / fix the 

The MP4 HD video file will be generated in the `ouput` directory at the end of the process as a single high quality video. You can open the directory at any time to see the process and intermediate artifacts. 

[Skill instructions](.claude/skills/motion-graphics-music-video/SKILL.md) · [Task reference](.claude/skills/motion-graphics-music-video/references/tasks.md) · [Testing](.claude/skills/motion-graphics-music-video/references/testing.md)

## Videos created with this skill

Six examples made with this skill. Follow a title to watch on YouTube.

| Video | Credits | Duration |
| --- | --- | --- |
| [The Math of You](https://youtu.be/TKXSOnVtfWQ) | HN - Suno | 3:25 |
| [You knew how to fork — take 2](https://youtu.be/b70F1bWZlwE) | @joshcirre | 1:26 |
| [You knew how to fork](https://youtu.be/Nxhg23_fheY) | @joshcirre | 1:26 |
| [Upping my P(doom) — remix #2](https://youtu.be/s8PmK6zD5RY) | Remix of donaldjewkes's video remix | 2:22 |
| [Symphony](https://youtu.be/UGX2KzetGZ0) | Elrosea · Opus 5.5 · SunoAI | — |
| [Parterre Girl](https://youtu.be/Zqd77QCaa58) | Core Refusal · Opus 5.5 · Suno | — |

The repository ships readable source files, including a small SVG icon, with no bundled binary media or fonts. The [icon recreation prompt](docs/icon-generation.md) and [production prompts](.claude/skills/motion-graphics-music-video/references/prompts.md) describe how to create assets in a separate video project. Plugin installation and MCP startup do not download assets or dependencies; project `setup` installs the production dependencies when explicitly run.

If you are looking for the motion graphics -no-image- version (No Image / Video Models) please see: https://github.com/makevoid/motion-graphics-music-video-skill-noimage 

<br>

## Quick start

1. Install the plugin from your terminal:

   ```sh
   claude plugin marketplace add makevoid/motion-graphics-music-video-skill
   claude plugin install motion-graphics-music-video@makevoid-music-video --scope user
   ```

2. Start `claude` in the terminal and set your Fal API key:

   ```text
   /plugin configure motion-graphics-music-video
   ```

   Enter your Fal AI key in the **Fal API key** field.

3. Open Claude Desktop, select **Code**, and start a new code session with access to a folder.

4. Run the skill, then supply your song and creative prompt:

   ```text
   /motion-graphics-music-video:motion-graphics-music-video
   ```

That's it. The plugin's `music-video` MCP server runs every Fal AI task with your key. Claude Code keeps the key in secure credential storage and passes it only to that server, so the Claude session never sees it.

## Usage

### Requirements

Before generating a video, you can install some of these dependencies, which on Mac OS should be easy to install - they're not required, you could prompt the skill to do as much as it can with just basic Ruby, NodeJS and Python but you get the best of results if you have everything as Opus will be able to have access to all the powerful tools in the toolkit

- Python 3 (should be installed already)
- Homebrew https://brew.sh/ - this is needed to install the other dependencies
- Ruby 3.2+ with Bundler (Mac OS comes with it with 2.6 - this should work as well but the agent will spend some time setting the project up, I recommend you try to install ruby via homebrew)
- Node.js 22+
- FFmpeg (from homebrew)
- ImageMagick (also from brew)
- Swift VFX and the full test suite require macOS 14+ with Swift 5.9+ / Xcode command line tools - that is very much optional but recommended

### Running the skill

In a Claude **Code** session with folder access, or a `claude` terminal session in the folder where you want to work, invoke:

```text
/motion-graphics-music-video:motion-graphics-music-video
```

Note: Use Claude Code from the terminal, the desktop version from my tests doesn't work this well.

Supply a song attachment or local path and a creative prompt. The skill will ask you with a message similar to this one:

## Prerequisites

Register a Fal.ai account and retrieve your API Key

https://fal.ai/docs/documentation/setting-up/authentication


## Example run

Invoking the skill in Claude Code produces output like this:

```text
─────────────────────────────────────────────────────────────────────────────────
❯ /motion-graphics-music-video:motion-graphics-music-video
─────────────────────────────────────────────────────────────────────────────────

⏺ Skill(motion-graphics-music-video:motion-graphics-music-video)
Successfully loaded skill

The motion-graphics-music-video skill is loaded. To start, I need two things:

1. The song: an attachment or a local path (mp3/wav/m4a).
2. A creative prompt: the concept, vibe, story or characters you want.

These are optional, and I'll use defaults for anything you leave out:
- Reference videos or images.
- Characters you want to keep. For example, the dreadlocks singer (char-singer-dreads) from the main repo.
- Aspect ratio. The default is 16:9 at 24fps, delivered at 1080p.
- Who the video is for.
- Budget. This sets the limit on paid fal calls and retries.

Once I have the song and prompt, I'll set up a separate project for it and analyze the song's beats and energy. I'll also research visual ideas online and write docs/PLAN.md with the character prompts, scene prompts and a cost estimate. I won't make any paid generation calls until you approve that plan.
```

Just providing the song + telling to do his best also works. Also providing the lyrics in songs where the lyrics are not perfectly audible improve generation.

---

The skill creates a separate video project, runs `setup` to install Ruby gems, npm packages, and a local Python environment there, then runs `doctor` to check dependencies. It asks you to approve its plan and budget before new generation trying also to do an estimate of the cost on Fal.ai. Dependencies and production files stay in the video project, outside the plugin installation.

Plugin sessions run it through the MCP server to include the configured key; a direct Bash invocation cannot see the plugin's sensitive option. 

You can stop reading here - the other notes in the readme are not this useful!

Hope you will have a blast with this!

---

### EXTRA NOTES:

---

### Contributions

I am looking for any contributions such as: 

- Running the skill and posting the output, upload / link your video and post or DM me on twitter 
- Adding other tools from Fal that are helpful to create videos
- Adding Nodejs P5JS effects / overlays / etc
- Adding Python tools for any kind of generic manipulation - even if they require packages to be installed - they may be worth it
- Swift VFX effects (I really think there's the most powerful chance here to do something unique as these are very good high quality libs that could create awesome effects that usually are blazing fast to be applied to the video files)
- other ideas and prompts (e.g. realism / other unexplored avenues)


### Note

I have a day job and this means I may have limited time to support / evolve this project.

Disclaimer: Use the code at your own risk.

### Task References

This section is mostly for agents - if you're Claude please read this:

See the [task reference](.claude/skills/motion-graphics-music-video/references/tasks.md) for environment overrides and setup details. `${CLAUDE_SKILL_DIR}` in the instructions is replaced by Claude Code with the installed skill's path; you do not need to export it in your shell.

### Disk Space

Please have a good amount of hard disk space available in your machine before starting, a 3m video could generate ~5GB in video assets, don't worry, after the video is generated you can delete them all.


### Fal API key

**Alternative FAL API Key Setup - Non interactive Setup:**

Enter your Fal API key in the plugin's **Fal API key** option, via its configuration prompt or `/plugin configure motion-graphics-music-video`. The `FAL_AI_API_KEY` option is marked sensitive: Claude Code masks it and stores it in secure credential storage. The plugin passes it through the environment to its bundled Ruby MCP server, which runs Fal tasks without placing the key in prompts or tool arguments. The option is optional so the `music-video` server always starts: when it is unset, the server falls back to a `FAL_AI_API_KEY` exported in the environment that launched Claude Code, and `credential_status` reports `configured: false` if neither is present. Change it through the plugin's configuration interface and restart/reconnect the server afterward.

For standalone development, set the environment variable in your terminal before running the Ruby toolkit:

```sh
export FAL_AI_API_KEY='your-fal-api-key'
```

This setting applies to direct CLI calls, a directly launched `scripts/mcp.rb`, and the installed plugin's server when its option is unset; a configured plugin option takes precedence. The old `FAL_KEY` variable and home-directory key file are no longer used. Keep actual keys out of chat, source files, and commits. See [credential setup and MCP task usage](.claude/skills/motion-graphics-music-video/references/credentials.md).

### Update the plugin

```sh
claude plugin marketplace update makevoid-music-video
claude plugin update motion-graphics-music-video@makevoid-music-video --scope user
```

Restart Claude Code after updating. Existing video projects retain their copied toolkit; updating the plugin affects future project initialization.

## Installation (legacy)

With Git and Claude Code installed, run these commands in your terminal:

```sh
claude plugin marketplace add makevoid/motion-graphics-music-video-skill
claude plugin install motion-graphics-music-video@makevoid-music-video --scope user
```

The user-scoped installation makes the plugin available across your projects. Claude Code downloads it from GitHub; you do not need a separate clone or symlink. See [Claude Code plugin installation](https://code.claude.com/docs/en/plugins/install) for other installation scopes.

To run it from the terminal instead of Claude Desktop, start a new Claude Code session in the directory where you want to work:

```sh
claude
```

Then invoke `/motion-graphics-music-video:motion-graphics-music-video` as described in [Usage](#usage).

## Local development and manual installation

To work on the plugin locally, clone the repository and validate both manifests:

```sh
git clone https://github.com/makevoid/motion-graphics-music-video-skill.git
cd motion-graphics-music-video-skill
claude plugin validate .claude-plugin/plugin.json --strict
claude plugin validate .claude-plugin/marketplace.json --strict
```

Load your local plugin for a session with `claude --plugin-dir /absolute/path/to/motion-graphics-music-video-skill` and use the same namespaced command shown above.

The repository also supports standalone skill use: start `claude` in the clone and invoke `/motion-graphics-music-video`. For standalone use across projects on macOS or Linux, run this from the clone's root:

```sh
mkdir -p ~/.claude/skills
ln -s "$PWD/.claude/skills/motion-graphics-music-video" \
  ~/.claude/skills/motion-graphics-music-video
```

Keep the clone in place because the link points to it. If the destination exists, inspect it before replacing it. Keep the whole skill folder, including its scripts, references, and assets. Update a manual clone with `git pull --ff-only`.

## Toolkit commands

From the repository root:

```sh
ruby .claude/skills/motion-graphics-music-video/scripts/mv.rb --help
ruby .claude/skills/motion-graphics-music-video/scripts/mv.rb setup
ruby .claude/skills/motion-graphics-music-video/scripts/mv.rb test
```

`rake test` is also a thin delegate to the Ruby entry point. All normal tests are local and make no paid Fal calls. Live tests require explicit paid-test opt-in; see the testing guide. The local full suite requires macOS for Swift VFX, Chrome, FFmpeg, ImageMagick, Node, Python and Ruby. No original project outputs, songs, secrets or generated characters are bundled. Fonts are selected from the host system and copied into each video workspace immediately before rendering; no font files are bundled.

## License

The plugin's original code and documentation are [MIT licensed](LICENSE). The [icon generation record](docs/icon-generation.md) documents the Nano Banana 2 high-thinking image and its resized PNG and SVG versions.

## External services and data sharing

The local MCP server and standalone CLI send data to external services:

- **Fal API and storage** (`queue.fal.run`, `rest.alpha.fal.ai`, provider-returned URLs including `*.fal.media`): API authentication, prompts, lyrics, settings, and selected audio/images/video for generation, transcription, and stem separation. Media URLs may be accessible to anyone with the link; remote assets are not automatically deleted. See [Fal's privacy policy](https://fal.ai/legal/privacy-policy).
- **Fal schemas** (`fal.ai/api/openapi/queue/openapi.json`): model identifiers for schema lookup.
- **Web research**: creative-brief search queries and reference URLs go to Claude's configured search provider and visited sites.
- **Dependencies and updates**: setup contacts RubyGems, npm, and PyPI (or configured mirrors) with package information; plugin installation and updates contact GitHub.
- **Local processing**: analysis, rendering, editing, and exports run locally. No maintainer telemetry or automatic social publishing is included. Normal Claude conversation and tool-result handling still applies.
