# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0](https://github.com/lettertwo/occurrence.nvim/compare/v1.0.0...v2.0.0) (2026-02-10)


### ⚠ BREAKING CHANGES

* **operators:** don't force nowait
* **operators:** add before hook and async ops
* **operators:** remove rot13
* **api:** lazy load everything but api descriptors
* **occurrence:** merge :add_pattern with :of_pattern
* **operators:** delete around occurrence by default
* place cursor at first edit location after operation
* **config:** replace on_activate callback with event
* **api:** prevent occurrence.get() from creating
* **api:** support command args, count, and range
* **operators:** simplify operator config
* **api:** change apply arg order
* **operators:** move operator logic to Occurrence
* **api:** dramatically reduce API surface
* **config:** restore <Plug> mappings
* **api:** rename iter_marks to iter; yield {id,range}
* **config:** support declarative keymap config
* **api:** move apply logic from Config to Occurrence
* **api:** rebrand 'preset' to 'occurrence mode'

### Features

* add Occurrence{Create,Dispose} events ([82a3e35](https://github.com/lettertwo/occurrence.nvim/commit/82a3e358ac58e25e5c10069260109f2b30be90ee))
* **api:** add occurrence:marks() method ([60e95b2](https://github.com/lettertwo/occurrence.nvim/commit/60e95b21be512b81a90cbba369d8f2f708993be3))
* **api:** add OccurrenceUpdate event ([b2baecc](https://github.com/lettertwo/occurrence.nvim/commit/b2baecca96ac75dc5d41f40b64e2094608a93056))
* **api:** support command args, count, and range ([fec928c](https://github.com/lettertwo/occurrence.nvim/commit/fec928c46b84872f2ecde0c81a663070b6fdf8e1))
* **config:** replace on_activate callback with event ([95918da](https://github.com/lettertwo/occurrence.nvim/commit/95918da188ecb805c978f423e5e234b680e33535))
* **config:** restore &lt;Plug&gt; mappings ([18c3c73](https://github.com/lettertwo/occurrence.nvim/commit/18c3c734875088615d16ffa170a1baf3c2837e55))
* **config:** support declarative keymap config ([1caca82](https://github.com/lettertwo/occurrence.nvim/commit/1caca820e2a327ebfcb22847359ae3d7f57c5415))
* **extmarks:** add current highlight; update defaults ([e642de6](https://github.com/lettertwo/occurrence.nvim/commit/e642de64746939c1fed4ec995d7047280568a5e6))
* **operators:** add after hook ([30e1111](https://github.com/lettertwo/occurrence.nvim/commit/30e1111597c143cb5f173343c93b36cb26d5e891))
* **operators:** add distribute operator ([4e9d2b2](https://github.com/lettertwo/occurrence.nvim/commit/4e9d2b229c48fe51aaed6e2963e463ebffea816a))
* **operators:** add Occurrence:apply_operator() method ([710647f](https://github.com/lettertwo/occurrence.nvim/commit/710647fb97190a7b38cd07cc862ae54ede016c5d))
* **range:** add range type (char|line|block) ([d4665d1](https://github.com/lettertwo/occurrence.nvim/commit/d4665d1be1ea4b184552b15daf0c1d314475d93d))


### Bug Fixes

* **api:** allow additional visual patterns ([f76c1bc](https://github.com/lettertwo/occurrence.nvim/commit/f76c1bc6bc5ec0d5a04db05d6b07b9f2fdaa028c))
* **api:** clear hlsearch after consuming search pattern ([9885642](https://github.com/lettertwo/occurrence.nvim/commit/9885642283e876f35b56520a0c2170b1dd814bda))
* **api:** execute operators as :Occurrence subcommands ([0af96bb](https://github.com/lettertwo/occurrence.nvim/commit/0af96bbb101f4ed4f56581993a7de82d2cba1eb5))
* **api:** modify_operator is a no-op outside of o mode ([03d123c](https://github.com/lettertwo/occurrence.nvim/commit/03d123c1007d96ee079326f224dc5aab0ef62729))
* **api:** pass range to iterate marks ([bba0680](https://github.com/lettertwo/occurrence.nvim/commit/bba06809b6b6dcef72d991064b2323ccad104daa))
* **api:** prevent occurrence.get() from creating ([4778849](https://github.com/lettertwo/occurrence.nvim/commit/4778849c1772a8f204339b7dc90790cb3e298f8b))
* **api:** prioritize marking search pattern over word ([e70cf6f](https://github.com/lettertwo/occurrence.nvim/commit/e70cf6f9a359ad5268bca82c62baa368f273ac91))
* **api:** run custom actions through apply ([726ed86](https://github.com/lettertwo/occurrence.nvim/commit/726ed867494d8807c5dd4aceba5b41419a77ab91))
* **command:** allow subcommands to execute against current config ([5185df3](https://github.com/lettertwo/occurrence.nvim/commit/5185df3f6725ac243870dfa77085902eba79a751))
* **config:** improve lazy loading ([a3b3f02](https://github.com/lettertwo/occurrence.nvim/commit/a3b3f0287b030f9bc7872cb9c5f157c18ce0f9da))
* Don't create occcurrence command until setup ([edc336a](https://github.com/lettertwo/occurrence.nvim/commit/edc336a4e205d4c852c377eef75b05f3b181079a))
* **extmarks:** make :add more resilient to bad ranges ([b9967e5](https://github.com/lettertwo/occurrence.nvim/commit/b9967e55060c550d6bd2cb0e122d79e1e32a5e10))
* **operators:** delete around occurrence by default ([346e5f2](https://github.com/lettertwo/occurrence.nvim/commit/346e5f254d055aebd113164d621ee11e208239fa))
* **operators:** don't force nowait ([09ad406](https://github.com/lettertwo/occurrence.nvim/commit/09ad40660a2889bf85a32fb417c56b0afcce7b7a))
* **operators:** expand around patterns more carefully ([e8be6cd](https://github.com/lettertwo/occurrence.nvim/commit/e8be6cd8d5062e33f8a0def05caf88132373fe20))
* **operators:** improve operator cancel detection ([638be6c](https://github.com/lettertwo/occurrence.nvim/commit/638be6c11d82707fbd57d5ee7f60d1a083fb6ae1))
* **operators:** operators should be repeatable after deactivation ([2a76588](https://github.com/lettertwo/occurrence.nvim/commit/2a76588199bea55903d0c185087320f9709bba82))
* place cursor at first edit location after operation ([c71fe3d](https://github.com/lettertwo/occurrence.nvim/commit/c71fe3d9d9360aaa8e28562e0edcd383d934e05e))
* set up autcommand when the plugin is loaded ([a002673](https://github.com/lettertwo/occurrence.nvim/commit/a002673e141b02e09522fb890581549a7ca3dee1))
* type error ([8c75ae5](https://github.com/lettertwo/occurrence.nvim/commit/8c75ae5935d71543013182ca643e3bb78c1c86b0))
* type errors ([34f625c](https://github.com/lettertwo/occurrence.nvim/commit/34f625c25ec9278ed1a922613361c2031d7f98f7))


### Documentation

* add custom operator docs ([b4f8fec](https://github.com/lettertwo/occurrence.nvim/commit/b4f8fec92431256d0ffe6a124db5810741bbb37d))
* add demos ([a92039c](https://github.com/lettertwo/occurrence.nvim/commit/a92039cae9ee97ff061012f4c74f65a71ccd43a6))
* add integration examples ([cefeb5e](https://github.com/lettertwo/occurrence.nvim/commit/cefeb5e51ccc179970df8ea7992695572a440ecf))
* add lazy loading notes ([6e1979e](https://github.com/lettertwo/occurrence.nvim/commit/6e1979e84d3168fc2ab988d32965305b97164953))
* **api:** add operator api docs ([fc0de4d](https://github.com/lettertwo/occurrence.nvim/commit/fc0de4dda8e7b436ad6bfbee44aaa04e9deb9fed))
* **api:** add some API docs ([eac1740](https://github.com/lettertwo/occurrence.nvim/commit/eac17406524b2a81120a2bb119d107446a2ed052))
* **api:** adds docs for events ([fa9cb2f](https://github.com/lettertwo/occurrence.nvim/commit/fa9cb2fe2b16eadc0db2d6fc8c83012d11003635))
* auto-update vimdoc [skip ci] ([ebc3779](https://github.com/lettertwo/occurrence.nvim/commit/ebc377993e5352f96cbc65e2b0319cb51eefbb5d))
* auto-update vimdoc [skip ci] ([90050c7](https://github.com/lettertwo/occurrence.nvim/commit/90050c76d356d3d16f926f366ca9b7bbd723dc39))
* auto-update vimdoc [skip ci] ([dd2d9a4](https://github.com/lettertwo/occurrence.nvim/commit/dd2d9a48cf6cb2339b76427aca4795013ef617aa))
* auto-update vimdoc [skip ci] ([5313299](https://github.com/lettertwo/occurrence.nvim/commit/53132993729f1089028e50c54b9352cc5fe1e170))
* clean up docs and tags ([876ad45](https://github.com/lettertwo/occurrence.nvim/commit/876ad45d3a0042bf6dcb377a235b585056851cb0))
* **command:** add command docs ([fe4aede](https://github.com/lettertwo/occurrence.nvim/commit/fe4aede5f48cb1dac61d96c75cb0e1fa40609b94))
* document custom operators ([a76c7ec](https://github.com/lettertwo/occurrence.nvim/commit/a76c7ec3d181df36a56714a45793eb6f1bb5f23c))
* improve API docs ([912bdf0](https://github.com/lettertwo/occurrence.nvim/commit/912bdf0435937ad42fbc5beb7031b3334b48c8f6))
* improve features section ([371c9d1](https://github.com/lettertwo/occurrence.nvim/commit/371c9d164db9697e73cb424f46720a802cddb7fa))
* improve gh md format of API docs ([3782e61](https://github.com/lettertwo/occurrence.nvim/commit/3782e6125e5563039df044f07f420d06730acaef))
* improve introductory description ([e3801ff](https://github.com/lettertwo/occurrence.nvim/commit/e3801ff335b4962367b9e2bff7f9b091e7679987))
* misc improvements ([e76c641](https://github.com/lettertwo/occurrence.nvim/commit/e76c64133488ad1289c375f8634bf3ac36d8e9b8))
* more cleanup ([24eaee0](https://github.com/lettertwo/occurrence.nvim/commit/24eaee0384c9d42b7cc53819afa6a264205f744b))
* move custom operators to wiki ([11d50fc](https://github.com/lettertwo/occurrence.nvim/commit/11d50fcd9567f322885c00a069c041b8ed435733))
* re-organize for better flow ([c65c0b2](https://github.com/lettertwo/occurrence.nvim/commit/c65c0b27d66ba72cd2cc763ccc864a7df41b1443))
* show keymaps and on_activate line-based examples ([15be00b](https://github.com/lettertwo/occurrence.nvim/commit/15be00bb3004ab519deb748c1668c489c80fe731))
* update config docs ([69aab6a](https://github.com/lettertwo/occurrence.nvim/commit/69aab6a9ba85fa8fdd27db33c138ea2cb8df45b6))
* update CONTRIBUTING docs ([ce3e003](https://github.com/lettertwo/occurrence.nvim/commit/ce3e003a07e3d4b1d3148fce881f88a9522e00df))
* update docs ([d852b24](https://github.com/lettertwo/occurrence.nvim/commit/d852b24b176a049c5c0ff868f7bbd643fbd36d24))


### Code Refactoring

* **api:** change apply arg order ([dfcb8bf](https://github.com/lettertwo/occurrence.nvim/commit/dfcb8bf8a20eede6ebeff221a2487a211ee9131a))
* **api:** dramatically reduce API surface ([2bd7192](https://github.com/lettertwo/occurrence.nvim/commit/2bd7192d4f1879ec25af1d89901806cb427ed632))
* **api:** lazy load everything but api descriptors ([8c51296](https://github.com/lettertwo/occurrence.nvim/commit/8c51296922112538a0c652fa3b6faa8c311f50f9))
* **api:** move apply logic from Config to Occurrence ([f08dcbc](https://github.com/lettertwo/occurrence.nvim/commit/f08dcbca43514592f38761f07e231704ace737fd))
* **api:** rebrand 'preset' to 'occurrence mode' ([a2a037f](https://github.com/lettertwo/occurrence.nvim/commit/a2a037fc8638c00082c25c8e0016c3d3ca4e6703))
* **api:** rename iter_marks to iter; yield {id,range} ([610ef48](https://github.com/lettertwo/occurrence.nvim/commit/610ef48b5738b75209d9a775c876f8b7ce74ab73))
* **api:** separate KeymapConfig from ApiConfig ([551a4ee](https://github.com/lettertwo/occurrence.nvim/commit/551a4eee427287b6a2563626a0c146b2c5178974))
* make default global keymaps explicit ([a750f67](https://github.com/lettertwo/occurrence.nvim/commit/a750f67698b6e358150c60a2197ee6aecb2bfec6))
* **occurrence:** merge :add_pattern with :of_pattern ([a584f1d](https://github.com/lettertwo/occurrence.nvim/commit/a584f1d937dc062c2a5b82e08544188984830652))
* **operators:** add before hook and async ops ([d540171](https://github.com/lettertwo/occurrence.nvim/commit/d540171e6bb3c64314b2eb05de612fb9b7d81fa8))
* **operators:** move operator logic to Occurrence ([0431386](https://github.com/lettertwo/occurrence.nvim/commit/0431386b57c94dc1efea41e75e7117f80613ddfc))
* **operators:** remove rot13 ([311499f](https://github.com/lettertwo/occurrence.nvim/commit/311499ff6c8c4fad00226bb7058c23c565cabcbf))
* **operators:** simplify operator config ([e26e9d1](https://github.com/lettertwo/occurrence.nvim/commit/e26e9d1d8edd4968e393d71b7edec8a740e97674))

## [0.3.0](https://github.com/lettertwo/occurrence.nvim/compare/v0.2.0...v0.3.0) (2026-01-14)


### Features

* **operators:** add after hook ([30e1111](https://github.com/lettertwo/occurrence.nvim/commit/30e1111597c143cb5f173343c93b36cb26d5e891))

## [0.2.0](https://github.com/lettertwo/occurrence.nvim/compare/v0.1.0...v0.2.0) (2026-01-08)


### ⚠ BREAKING CHANGES

* **operators:** don't force nowait
* **operators:** add before hook and async ops
* **operators:** remove rot13
* **api:** lazy load everything but api descriptors
* **occurrence:** merge :add_pattern with :of_pattern
* **operators:** delete around occurrence by default
* place cursor at first edit location after operation
* **config:** replace on_activate callback with event
* **api:** prevent occurrence.get() from creating
* **api:** support command args, count, and range
* **operators:** simplify operator config
* **api:** change apply arg order
* **operators:** move operator logic to Occurrence
* **api:** dramatically reduce API surface
* **config:** restore <Plug> mappings
* **api:** rename iter_marks to iter; yield {id,range}
* **config:** support declarative keymap config
* **api:** move apply logic from Config to Occurrence
* **api:** rebrand 'preset' to 'occurrence mode'

### Features

* add Occurrence{Create,Dispose} events ([82a3e35](https://github.com/lettertwo/occurrence.nvim/commit/82a3e358ac58e25e5c10069260109f2b30be90ee))
* **api:** add occurrence:marks() method ([60e95b2](https://github.com/lettertwo/occurrence.nvim/commit/60e95b21be512b81a90cbba369d8f2f708993be3))
* **api:** add OccurrenceUpdate event ([b2baecc](https://github.com/lettertwo/occurrence.nvim/commit/b2baecca96ac75dc5d41f40b64e2094608a93056))
* **api:** support command args, count, and range ([fec928c](https://github.com/lettertwo/occurrence.nvim/commit/fec928c46b84872f2ecde0c81a663070b6fdf8e1))
* **config:** replace on_activate callback with event ([95918da](https://github.com/lettertwo/occurrence.nvim/commit/95918da188ecb805c978f423e5e234b680e33535))
* **config:** restore &lt;Plug&gt; mappings ([18c3c73](https://github.com/lettertwo/occurrence.nvim/commit/18c3c734875088615d16ffa170a1baf3c2837e55))
* **config:** support declarative keymap config ([1caca82](https://github.com/lettertwo/occurrence.nvim/commit/1caca820e2a327ebfcb22847359ae3d7f57c5415))
* **extmarks:** add current highlight; update defaults ([e642de6](https://github.com/lettertwo/occurrence.nvim/commit/e642de64746939c1fed4ec995d7047280568a5e6))
* **operators:** add distribute operator ([4e9d2b2](https://github.com/lettertwo/occurrence.nvim/commit/4e9d2b229c48fe51aaed6e2963e463ebffea816a))
* **operators:** add Occurrence:apply_operator() method ([710647f](https://github.com/lettertwo/occurrence.nvim/commit/710647fb97190a7b38cd07cc862ae54ede016c5d))
* **range:** add range type (char|line|block) ([d4665d1](https://github.com/lettertwo/occurrence.nvim/commit/d4665d1be1ea4b184552b15daf0c1d314475d93d))


### Bug Fixes

* **api:** allow additional visual patterns ([f76c1bc](https://github.com/lettertwo/occurrence.nvim/commit/f76c1bc6bc5ec0d5a04db05d6b07b9f2fdaa028c))
* **api:** clear hlsearch after consuming search pattern ([9885642](https://github.com/lettertwo/occurrence.nvim/commit/9885642283e876f35b56520a0c2170b1dd814bda))
* **api:** execute operators as :Occurrence subcommands ([0af96bb](https://github.com/lettertwo/occurrence.nvim/commit/0af96bbb101f4ed4f56581993a7de82d2cba1eb5))
* **api:** modify_operator is a no-op outside of o mode ([03d123c](https://github.com/lettertwo/occurrence.nvim/commit/03d123c1007d96ee079326f224dc5aab0ef62729))
* **api:** pass range to iterate marks ([bba0680](https://github.com/lettertwo/occurrence.nvim/commit/bba06809b6b6dcef72d991064b2323ccad104daa))
* **api:** prevent occurrence.get() from creating ([4778849](https://github.com/lettertwo/occurrence.nvim/commit/4778849c1772a8f204339b7dc90790cb3e298f8b))
* **api:** prioritize marking search pattern over word ([e70cf6f](https://github.com/lettertwo/occurrence.nvim/commit/e70cf6f9a359ad5268bca82c62baa368f273ac91))
* **api:** run custom actions through apply ([726ed86](https://github.com/lettertwo/occurrence.nvim/commit/726ed867494d8807c5dd4aceba5b41419a77ab91))
* **command:** allow subcommands to execute against current config ([5185df3](https://github.com/lettertwo/occurrence.nvim/commit/5185df3f6725ac243870dfa77085902eba79a751))
* **config:** improve lazy loading ([a3b3f02](https://github.com/lettertwo/occurrence.nvim/commit/a3b3f0287b030f9bc7872cb9c5f157c18ce0f9da))
* Don't create occcurrence command until setup ([edc336a](https://github.com/lettertwo/occurrence.nvim/commit/edc336a4e205d4c852c377eef75b05f3b181079a))
* **extmarks:** make :add more resilient to bad ranges ([b9967e5](https://github.com/lettertwo/occurrence.nvim/commit/b9967e55060c550d6bd2cb0e122d79e1e32a5e10))
* **operators:** delete around occurrence by default ([346e5f2](https://github.com/lettertwo/occurrence.nvim/commit/346e5f254d055aebd113164d621ee11e208239fa))
* **operators:** don't force nowait ([09ad406](https://github.com/lettertwo/occurrence.nvim/commit/09ad40660a2889bf85a32fb417c56b0afcce7b7a))
* **operators:** expand around patterns more carefully ([e8be6cd](https://github.com/lettertwo/occurrence.nvim/commit/e8be6cd8d5062e33f8a0def05caf88132373fe20))
* **operators:** improve operator cancel detection ([638be6c](https://github.com/lettertwo/occurrence.nvim/commit/638be6c11d82707fbd57d5ee7f60d1a083fb6ae1))
* **operators:** operators should be repeatable after deactivation ([2a76588](https://github.com/lettertwo/occurrence.nvim/commit/2a76588199bea55903d0c185087320f9709bba82))
* place cursor at first edit location after operation ([c71fe3d](https://github.com/lettertwo/occurrence.nvim/commit/c71fe3d9d9360aaa8e28562e0edcd383d934e05e))
* set up autcommand when the plugin is loaded ([a002673](https://github.com/lettertwo/occurrence.nvim/commit/a002673e141b02e09522fb890581549a7ca3dee1))
* type error ([8c75ae5](https://github.com/lettertwo/occurrence.nvim/commit/8c75ae5935d71543013182ca643e3bb78c1c86b0))
* type errors ([34f625c](https://github.com/lettertwo/occurrence.nvim/commit/34f625c25ec9278ed1a922613361c2031d7f98f7))


### Documentation

* add custom operator docs ([b4f8fec](https://github.com/lettertwo/occurrence.nvim/commit/b4f8fec92431256d0ffe6a124db5810741bbb37d))
* add integration examples ([cefeb5e](https://github.com/lettertwo/occurrence.nvim/commit/cefeb5e51ccc179970df8ea7992695572a440ecf))
* add lazy loading notes ([6e1979e](https://github.com/lettertwo/occurrence.nvim/commit/6e1979e84d3168fc2ab988d32965305b97164953))
* **api:** add operator api docs ([fc0de4d](https://github.com/lettertwo/occurrence.nvim/commit/fc0de4dda8e7b436ad6bfbee44aaa04e9deb9fed))
* **api:** add some API docs ([eac1740](https://github.com/lettertwo/occurrence.nvim/commit/eac17406524b2a81120a2bb119d107446a2ed052))
* **api:** adds docs for events ([fa9cb2f](https://github.com/lettertwo/occurrence.nvim/commit/fa9cb2fe2b16eadc0db2d6fc8c83012d11003635))
* auto-update vimdoc [skip ci] ([ebc3779](https://github.com/lettertwo/occurrence.nvim/commit/ebc377993e5352f96cbc65e2b0319cb51eefbb5d))
* auto-update vimdoc [skip ci] ([90050c7](https://github.com/lettertwo/occurrence.nvim/commit/90050c76d356d3d16f926f366ca9b7bbd723dc39))
* auto-update vimdoc [skip ci] ([dd2d9a4](https://github.com/lettertwo/occurrence.nvim/commit/dd2d9a48cf6cb2339b76427aca4795013ef617aa))
* auto-update vimdoc [skip ci] ([5313299](https://github.com/lettertwo/occurrence.nvim/commit/53132993729f1089028e50c54b9352cc5fe1e170))
* clean up docs and tags ([876ad45](https://github.com/lettertwo/occurrence.nvim/commit/876ad45d3a0042bf6dcb377a235b585056851cb0))
* **command:** add command docs ([fe4aede](https://github.com/lettertwo/occurrence.nvim/commit/fe4aede5f48cb1dac61d96c75cb0e1fa40609b94))
* document custom operators ([a76c7ec](https://github.com/lettertwo/occurrence.nvim/commit/a76c7ec3d181df36a56714a45793eb6f1bb5f23c))
* improve API docs ([912bdf0](https://github.com/lettertwo/occurrence.nvim/commit/912bdf0435937ad42fbc5beb7031b3334b48c8f6))
* improve features section ([371c9d1](https://github.com/lettertwo/occurrence.nvim/commit/371c9d164db9697e73cb424f46720a802cddb7fa))
* improve gh md format of API docs ([3782e61](https://github.com/lettertwo/occurrence.nvim/commit/3782e6125e5563039df044f07f420d06730acaef))
* improve introductory description ([e3801ff](https://github.com/lettertwo/occurrence.nvim/commit/e3801ff335b4962367b9e2bff7f9b091e7679987))
* misc improvements ([e76c641](https://github.com/lettertwo/occurrence.nvim/commit/e76c64133488ad1289c375f8634bf3ac36d8e9b8))
* more cleanup ([24eaee0](https://github.com/lettertwo/occurrence.nvim/commit/24eaee0384c9d42b7cc53819afa6a264205f744b))
* move custom operators to wiki ([11d50fc](https://github.com/lettertwo/occurrence.nvim/commit/11d50fcd9567f322885c00a069c041b8ed435733))
* re-organize for better flow ([c65c0b2](https://github.com/lettertwo/occurrence.nvim/commit/c65c0b27d66ba72cd2cc763ccc864a7df41b1443))
* show keymaps and on_activate line-based examples ([15be00b](https://github.com/lettertwo/occurrence.nvim/commit/15be00bb3004ab519deb748c1668c489c80fe731))
* update config docs ([69aab6a](https://github.com/lettertwo/occurrence.nvim/commit/69aab6a9ba85fa8fdd27db33c138ea2cb8df45b6))
* update CONTRIBUTING docs ([ce3e003](https://github.com/lettertwo/occurrence.nvim/commit/ce3e003a07e3d4b1d3148fce881f88a9522e00df))
* update docs ([d852b24](https://github.com/lettertwo/occurrence.nvim/commit/d852b24b176a049c5c0ff868f7bbd643fbd36d24))


### Code Refactoring

* **api:** change apply arg order ([dfcb8bf](https://github.com/lettertwo/occurrence.nvim/commit/dfcb8bf8a20eede6ebeff221a2487a211ee9131a))
* **api:** dramatically reduce API surface ([2bd7192](https://github.com/lettertwo/occurrence.nvim/commit/2bd7192d4f1879ec25af1d89901806cb427ed632))
* **api:** lazy load everything but api descriptors ([8c51296](https://github.com/lettertwo/occurrence.nvim/commit/8c51296922112538a0c652fa3b6faa8c311f50f9))
* **api:** move apply logic from Config to Occurrence ([f08dcbc](https://github.com/lettertwo/occurrence.nvim/commit/f08dcbca43514592f38761f07e231704ace737fd))
* **api:** rebrand 'preset' to 'occurrence mode' ([a2a037f](https://github.com/lettertwo/occurrence.nvim/commit/a2a037fc8638c00082c25c8e0016c3d3ca4e6703))
* **api:** rename iter_marks to iter; yield {id,range} ([610ef48](https://github.com/lettertwo/occurrence.nvim/commit/610ef48b5738b75209d9a775c876f8b7ce74ab73))
* **api:** separate KeymapConfig from ApiConfig ([551a4ee](https://github.com/lettertwo/occurrence.nvim/commit/551a4eee427287b6a2563626a0c146b2c5178974))
* make default global keymaps explicit ([a750f67](https://github.com/lettertwo/occurrence.nvim/commit/a750f67698b6e358150c60a2197ee6aecb2bfec6))
* **occurrence:** merge :add_pattern with :of_pattern ([a584f1d](https://github.com/lettertwo/occurrence.nvim/commit/a584f1d937dc062c2a5b82e08544188984830652))
* **operators:** add before hook and async ops ([d540171](https://github.com/lettertwo/occurrence.nvim/commit/d540171e6bb3c64314b2eb05de612fb9b7d81fa8))
* **operators:** move operator logic to Occurrence ([0431386](https://github.com/lettertwo/occurrence.nvim/commit/0431386b57c94dc1efea41e75e7117f80613ddfc))
* **operators:** remove rot13 ([311499f](https://github.com/lettertwo/occurrence.nvim/commit/311499ff6c8c4fad00226bb7058c23c565cabcbf))
* **operators:** simplify operator config ([e26e9d1](https://github.com/lettertwo/occurrence.nvim/commit/e26e9d1d8edd4968e393d71b7edec8a740e97674))

## [Unreleased]

### Added

- Modern documentation generation with panvimdoc
- Automated release management with LuaRocks
- LuaCATS annotations for type safety
- Comprehensive performance tests
- CI/CD workflows for testing and releases
- Support for modern plugin managers (rocks.nvim, lazy.nvim v11)

### Changed

- Replaced lemmy-help with panvimdoc for documentation generation
- Updated README.md with comprehensive usage examples
- Modernized project structure following 2024 best practices
- Improved Makefile with better test targets

### Fixed

- Performance test thresholds and memory leak detection
- Better error handling and resource cleanup

## [0.1.0] - Initial Release

### Added

- Core occurrence functionality
- Multiple interaction modes (occurrence mode, operator-modifier)
- Smart occurrence detection (word, selection, search patterns)
- Visual highlighting using Neovim's extmarks system
- Native vim operator integration
- Configurable keymaps and behavior
- Performance optimizations for large files

[Unreleased]: https://github.com/lettertwo/occurrence.nvim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/lettertwo/occurrence.nvim/releases/tag/v0.1.0
