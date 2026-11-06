# Character, image-edit and H3 prompts

Use this creative directive in each character/scene/H3 prompt and sub-agent brief, followed by specific visual instructions:

> This asset belongs to a hyper quality, very interesting and potentially very fun viral music video. Deliver polished visual detail and expressive character animation, with surprising, relevant ideas from the researched creative plan. The overall video defaults to energetic, chaotic choreography that constantly hooks attention while keeping its main action readable.

The chaos in that directive belongs to the p5 choreography (scale changes, entrances, graphics, cuts), not to the generated frame. Every H3 clip is one clear character performance; every generated image is one clean subject.

For a still image, specify the lively pose/expression that will support animation; do not ask a still generator to produce motion. Do not instruct the generation model to browse: the coordinating agent performs web search and supplies the selected details. Reuse the approved style paragraph in every prompt.

## Self-contained characters (default)

Videos composed from keyed character sprites over p5 graphics perform much better than videos whose scenes are generated whole by H3. H3 redraws a background on every frame, so props morph, colours drift away from the palette, the camera wanders and invented text appears; p5 can no longer place graphics behind the character, reposition the performance or change the scene without paying for a new take. Treat the rules below as constraints, not suggestions:

- **H3 animates characters only.** One character per clip, on perfectly flat chroma green #00B140, locked camera, no zoom, no floor, no cast shadow, no props beyond what the character holds or wears. The whole silhouette stays inside the frame with a margin, including the hands at the widest point of the gesture.
- **The world belongs to p5 and still plates.** Environments, props, diagrams, text, camera moves, transitions and light are p5 (or Swift VFX). A generated background is a still image plate with no people, generated in the same style paragraph, and held or moved by p5.
- **Characters meet in p5.** Do not generate two characters in the same H3 clip. Generate each separately, with eyelines and facing direction planned in the keyframe prompts, and composite them. A still image with both characters (a thumbnail, a poster frame) is fine.
- **One pose per keyframe.** Each keyframe is one character, one framing, one starting pose for one performance. Give framing as a percentage of frame height and state the facing direction.
- **Full-frame H3 is an exception.** Use it at most once or twice in a video, only where the character must physically interact with a generated object, and justify each use in the plan. Keep it to a plain background consistent with the approved art direction, a single prop, a locked camera and a short duration.

## Style bible and colour consistency

Write one style paragraph in the plan and paste it verbatim into every image prompt. Derive the look from the song, brief and references; specify the rendering medium, forms, materials, lighting, texture, backgrounds and colour treatment that matter for that look. Describe line and fill treatments when applicable. Choose palette size, gradients, tonal range and surface detail to suit the direction. A limited hex palette is useful when the chosen style calls for it; natural shading and colour variation are valid too. Keep generated lettering excluded so final typography remains under p5 control.

Define shared colour constants in p5 for specified palette anchors and accents. Match graphics, typography and light cues to the approved colour treatment, including any planned gradients, shading or scene-specific lighting. Keep characters, plates and graphics visually coherent. Select fonts, weights, text effects and textures for the brief. Before rendering, scan installed macOS fonts and copy the selected files into the video workspace as described in [Project fonts](animation-audio-vfx.md#project-fonts); the plugin bundles no fonts. Character cutouts describe the compositing method, not a paper-cutout appearance.

## Identity sheets: GPT Image 2.6 Sunburst high quality / high reasoning

Default class `Fal::Models::GptImage26`, endpoint `openai/gpt-image-2.6/sunburst/text-to-image`. Write `prompts/char-<id>-v1/01_ref_base.txt` with the actual prompt. Request one coherent character sheet: front full body, profile/back if useful, and distinct expressions; specify proportions, silhouette, hair, clothing, face and color anchors. Keep sufficient limb margins. Ban lettering, captions and watermarks; p5 draws final typography.

Inspect the face and hands, anatomy, silhouette and expression range. Accept a reference only after visual review. New shots use edits of this reference; never reconstruct identity from prose alone.

## Editing/adding/replacing characters

`Fal::Models::GptImage26Edit` calls `openai/gpt-image-2.6/sunburst/edit` with `quality: "high"` and `reasoning_effort: "high"`. `02_keyframes.yml` can specify `base`, `refs` and `prompt`. State “same character and same approved visual style,” with one intentional change per edit. Specify composition by percent of frame, face bounds and empty areas for planned text. Keep reference image ordering explicit for multiple characters.

For an approved swap, create `char-<id>-v2` or a versioned edited keyframe. Review it; update dependent runs/prompts; regenerate only affected keyframes/clips/overlays. Recompute sprite crop boxes and placement when hair, costume or silhouette changes. Preserve v1 and its accepted takes. A newly added cast member gets a separate identity run, linked into the same style bible.

## Animation: MiniMax H3 Max 1080P

`Fal::Models::H3MaxImageToVideo`, endpoint `minimax/h3-max/image-to-video`; defaults `resolution: 1080P`, prompt expansion disabled. The shipped pipeline uses 5–15 second clips; check the fetched schema before generation. Split long actions, and trim longer silent clips for brief edits. Never retime visible singing.

Prompt structure: identity/style → framing → exact lyric/performance → two or three timed acting beats → camera → background invariants → exclusions. Describe articulation, jaw and cheek motion, pauses, glances, head tilts, shoulder/hand acting and follow-through. Avoid a floating still portrait with only camera movement.

Example: same approved singer, medium close-up; articulates the supplied lyric with a closed mouth during its pause, raises one eyebrow on the punchline and turns toward screen-right on the final word. Keep the whole face visible. Every clip is a cutout unless the plan justifies an exception (see "Self-contained characters"), so every H3 prompt ends with the cutout invariants: locked camera, no camera movement, no zoom, feet/limbs within frame, perfectly flat chroma green #00B140 throughout, no green clothes, no shadows on the background, no floor, no text, no extra people, preserve the approved visual style.

If a take invents lyric captions despite the exclusion, inspect whether they touch the character or props before choosing a repair. For a retry, keep the aligned vocal input and acting beats but remove the quoted transcript from the visual prompt; the model may otherwise render those words. This is a prompt adjustment to review, not a guarantee. Keep the exact lyric/timing transcript in the plan and p5 cue data.

Use `audio:` as a full-song-aligned vocal WAV and `audio_at:` in **section-local seconds**. The Ruby Clips service adds `music_offset` before cutting audio. Place it with `clip.at(section_local_t)` so the local offset is honored. H3 requires target audio at least two seconds long; pad a short ending with silence rather than shifting the words. Gate bleed only after listening; do not cut soft consonants.

Fal describes `target_audio_url` as soundtrack pinning. It is not a contractual guarantee of phoneme-accurate lipsync. Inspect opening and peak performance at normal speed, slow playback and mouth crops. The local mouth-energy heuristic only helps find gross lag/continued talking in pauses; it cannot certify visemes. Re-prompt/regenerate within the allowance if the visible performance is wrong.

## Models and evolving schemas

Fetch `openapi:fetch` and read `openapi:summary`. The wrappers validate known properties/enums/ranges when schemas exist; inspect nested/union constraints when extending a call. Add any other Fal audio/image/video model as a Ruby `Fal::Models::Base` subclass, then a service/task. Do not call an SDK or curl directly. Do not silently substitute a model or quality setting.

Official sources: [H3 API](https://fal.ai/models/minimax/h3-max/image-to-video/api), [Sunburst generation](https://fal.ai/models/openai/gpt-image-2.6/sunburst/text-to-image/api), [Sunburst edit](https://fal.ai/models/openai/gpt-image-2.6/sunburst/edit/api). Defaults were checked when this skill was built; refresh schemas for a new production.
