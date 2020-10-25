Wayland Embedded View Framework: Server
=======================================

* Development status: 💩 prototype 💩
* Maintainer: Jiří Janoušek
* License: [BSD-2-Clause](./LICENSE)
* Issues tracker: [Show issues][1] | [Create issue][2]

Components
----------

* The `wevp_embed` protocol: [protocols/wevp-embed.xml](./protocol/wevp-embed.xml)
* Server implementation in Vala/GTK+ 3: [src/](./src)
* Client implementation in Python: FIXME

Dependencies
------------

* Wayland Server library
* OpenGL library
* GTK+ 3 library
* Vala compiler
* GNU Make

Build from source
-----------------

`make all`

Run
---

`make run` - Starts a new server listening on `$XDG_RUNTIME_DIR/wevf-demo`.

Copyright
---------

* Copyright 2020 Jiří Janoušek <janousek.jiri@gmail.com>
* License: [BSD-2-Clause](./LICENSE)

[1]: https://github.com/tiliado/wayland-embedded-view-server/issues
[2]: https://github.com/tiliado/wayland-embedded-view-server/issues/new
